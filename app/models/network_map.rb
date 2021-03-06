class NetworkMap < ActiveRecord::Base
  include SingularTable
  include SoftDelete
  include Cacheable
  include Bootsy::Container

  delegate :url_helpers, to: 'Rails.application.routes'

  belongs_to :sf_guard_user, foreign_key: "user_id", inverse_of: :network_maps
  belongs_to :user, foreign_key: "user_id", primary_key: "sf_guard_user_id", inverse_of: :network_maps

  has_many :topic_maps, inverse_of: :map
  has_many :topics, through: :topic_maps, inverse_of: :maps

  delegate :user, to: :sf_guard_user

  scope :featured, -> { where(is_featured: true) }
  scope :public_scope, -> { where(is_private: false) }
  scope :private_scope, -> { where(is_private: true) }

  validates_presence_of :title

  before_save :set_defaults, :generate_index_data

  def generate_index_data
    hash = JSON.parse(data)
    nodes = hash['entities'].map { |e| [ e['name'], e['description'] ] }.flatten.compact.join(', ')
    texts = hash['texts'].present? ? hash['texts'].map { |t| t['text'] }.join(', ') : ''
    self.index_data = nodes + ', ' + texts
  end

  def set_defaults
    self.data = JSON.dump({ entities: [], rels: [], texts: [] }) if data.blank?
    self.width = Lilsis::Application.config.netmap_default_width if width.blank?
    self.height = Lilsis::Application.config.netmap_default_width if height.blank?
    self.zoom = '1' if zoom.blank?
  end

  def prepared_data
    hash = JSON.parse(data)
    json = JSON.dump({ 
      entities: hash['entities'].map { |entity| self.class.prepare_entity(entity) },
      rels: hash['rels'].map { |rel| self.class.prepare_rel(rel) },
      texts: hash['texts'].present? ? hash['texts'].map { |text| self.class.prepare_text(text) } : []
    })
    ERB::Util.json_escape(json)
  end

  def rels
    hash = JSON.parse(data)
    rel_ids = hash['rels'].map { |m| m['id'] }.select{ |id| id.to_i != 0 }
    return [] if rel_ids.empty?
    Relationship.where(id: rel_ids)
  end

  def references
    rels.collect{ |r| r.references }.flatten.uniq(&:source).reject{ |ref| ref.name.blank? }.sort_by{ |ref| ref.updated_at }.reverse
  end

  def self.entity_type(entity)
    return entity['type'] if entity['type'].present?
    
    if entity['primary_ext'].present?
      return entity['primary_ext']
    else
      if entity['url'].present? and entity['url'].match(/person\/\d+\//)
        return 'Person'
      elsif entity['url'].present? and entity['url'].match(/org\/\d+\//)
        return 'Org'
      else
        return nil
      end
    end
  end

  def self.is_custom_entity?(entity)
    if entity['custom'].present?
      entity['custom']
    else
      entity['id'].to_s[0] == "x"
    end
  end

  def self.prepare_entity(entity)
    type = entity_type(entity)

    if entity['image'] and !entity['image'].include?('netmap') and !entity['image'].include?('anon')
      image_path = entity['image']
    elsif entity['filename']
      image_path = Image.image_path(entity['filename'], 'profile')
    else
      if type == 'Person'
        image_path = ActionController::Base.helpers.image_path('netmap-person.png')
      elsif type == 'Org'
        image_path = ActionController::Base.helpers.image_path('netmap-org.png')
      else
        image_path = nil
      end
    end

    if is_custom_entity?(entity)
      url = entity['url']
    else
      url = ActionController::Base.helpers.url_for(Entity.legacy_url(type, entity['id'], entity['name']))
    end

    {
      id: is_custom_entity?(entity) ? entity['id'] : self.integerize(entity['id']),
      name: entity['name'],
      image: image_path,
      url: url,
      description: (entity['blurb'] || entity['description']),
      x: entity['x'],
      y: entity['y'],
      fixed: true,
      type: type,
      hide_image: entity['hide_image'].present? ? entity['hide_image'] : false,
      custom: is_custom_entity?(entity),
      scale: entity['scale']
    }
  end

  def self.is_custom_rel?(rel)
    if rel['custom'].present?
      rel['custom']
    else
      rel['id'].to_s[0] == "x"
    end
  end

  def self.prepare_rel(rel)
    if is_custom_rel?(rel)
      url = rel['url']
    else
      url = ActionController::Base.helpers.url_for(Relationship.legacy_url(rel['id']))
    end

    # backward compatibility for maps created before rels could have multiple categories
    cat_ids = rel['category_ids'].present? ? rel['category_ids'] : [rel['category_id']].compact

    {
      id: is_custom_rel?(rel) ? rel['id'] : self.integerize(rel['id']),
      entity1_id: rel['entity1_id'].to_s[0] == "x" ? rel['entity1_id'].to_s : self.integerize(rel['entity1_id']),
      entity2_id: rel['entity2_id'].to_s[0] == "x" ? rel['entity2_id'].to_s : self.integerize(rel['entity2_id']),
      category_id: self.integerize(rel['category_id']),
      category_ids: Array(self.integerize(cat_ids)),
      is_current: self.integerize(rel['is_current']),
      is_directional: rel['is_directional'],
      end_date: rel['end_date'],
      scale: rel['scale'],
      label: rel['label'],
      url: url,
      x1: rel['x1'],
      y1: rel['y1'],
      fixed: true,
      custom: is_custom_rel?(rel)
    }
  end

  def self.prepare_text(text)
    text
  end

  def self.integerize(value)
    return nil if value.nil?
    return value.map { |elem| integerize(elem) } if value.instance_of?(Array)
    return integerize(value.split(',')) if value.instance_of?(String) and value.include?(',')
    return nil if value.to_i == 0 and value != "0"
    value.to_i
  end

  def name
    return "Map #{id}" if title.blank?
    title
  end

  def to_param
    title.nil? ? id.to_s : "#{id}-#{title.parameterize}"
  end

  def share_text
    title.nil? ? "Network map #{id}" : "Map of #{title}"
  end

  def generate_s3_thumb(s3 = nil)
    s3 = S3.s3 if s3.nil?
    bucket = s3.buckets[Lilsis::Application.config.aws_s3_bucket]

    url = Rails.application.routes.url_helpers.raw_map_url(self)
    local_path = "tmp/map-#{id}.png"
    s3_path = "images/maps/#{to_param}.png"

    system("phantomjs vendor/assets/javascripts/makemaps.js #{url} #{local_path}")

    obj = bucket.objects[s3_path]
    obj.write(Pathname.new(local_path), { acl: :public_read })

    File.delete(local_path)
    self.thumbnail = S3.url("/" + s3_path) if obj.exists?
    save
  end

  def self.entities_for_map(entity_ids)
    interlocks = Link.interlock_hash_from_entities(entity_ids).select { |k, v| v.count > 1 }.sort { |a, b| a[1].count <=> b[1].count }
    ids = []
    interlocks.each do |id, ary|
      break if ids.count + ary.count > 30
      ids = entity_ids.concat([id]).concat(ary).uniq
    end
    ids
  end

  def self.create_from_entities(title, user_id, entity_ids)
    entity_ids = entities_for_map(entity_ids)
    entities = Entity.joins("LEFT JOIN image ON (image.entity_id = entity.id AND image.is_featured = 1)").where(id: entity_ids).select("entity.*, image.filename")
    rels = rels_from_entities(entities.map(&:id))
    data = ERB::Util.json_escape(JSON.dump({ 
      entities: entities.map { |entity| prepare_entity(entity) },
      rels: rels.map { |rel| prepare_rel(rel) },
      texts: []
    }))
    sf_guard_user_id = User.find(user_id).sf_guard_user_id
    create(title: title, user_id: sf_guard_user_id, data: data)
  end

  def self.rels_from_entities(entity_ids)
    sql = "SELECT r.id, r.entity1_id, r.entity2_id, r.category_id, r.is_current, r.end_date, r.is_deleted, " + 
          "GROUP_CONCAT(DISTINCT(rc.name) SEPARATOR ', ') AS label, " + 
          "GROUP_CONCAT(DISTINCT(r.category_id) SEPARATOR ',') AS category_ids, " + 
          "COUNT(r.id) AS num " +
          "FROM relationship r LEFT JOIN relationship_category rc ON (rc.id = r.category_id) " +
          "LEFT JOIN entity e1 ON (e1.id = r.entity1_id) " +
          "LEFT JOIN entity e2 ON (e2.id = r.entity2_id) " +
          "WHERE r.entity1_id IN (" + entity_ids.join(',') + ") " +
          "AND r.entity2_id IN (" + entity_ids.join(',') + ") " +
          "AND r.is_deleted = 0 " +
          "AND r.entity1_id <> r.entity2_id " +
          "AND e1.is_deleted = 0 AND e2.is_deleted = 0 " +
          "GROUP BY LEAST(r.entity1_id, r.entity2_id), GREATEST(r.entity1_id, r.entity2_id), r.category_id"
    rels = ActiveRecord::Base.connection.exec_query(sql)
  end
end
