class ListDatatable
  include RelationshipsHelper
  include ApplicationHelper
  include Rails.application.routes.url_helpers

  attr_reader :list, :links, :types, :industries, :entities, :interlocks, :list_interlocks

  def initialize(list, force_interlocks=false)
    @list = list
    @entity_ids = @list.entity_ids
    @force_interlocks = force_interlocks
    @num_interlocks = @num_lists = 20
    @types = []
    @industries = []
    @lists = []
  end

  def generate_data
    get_interlocks
    get_lists
    get_data
    prepare_options
  end

  def data
    generate_data unless @data.present?
    @data
  end

  def get_interlocks
    @links = Link.includes(:relationship).where(entity1_id: @entity_ids, category_id: [1, 3], relationship: { is_deleted: 0 }).where.not(entity2_id: @entity_ids).limit(10000)
    @num_links = @links.count

    if interlocks?
      interlocks = Link.interlock_hash(@links)
      @top_interlocks = interlocks.select { |k, v| v.count > 1 }.sort { |a, b| a[1].count <=> b[1].count }.reverse.take(@num_interlocks)
      entities = Entity.where(id: @top_interlocks.map { |a| a[0] }).group_by(&:id)
      @interlocks = [["Connected To", ""]].concat(@top_interlocks.map { |a| e = entities[a[0]].first; [e.name + " (#{interlocks[e.id].count})", e.id] })
    end
  end

  def get_lists
    if lists?
      interlocks = @list.interlocks_hash
      @top_list_interlocks = interlocks.select { |k, v| v.count > 1 }.sort { |a, b| a[1].count <=> b[1].count }.reverse.take(@num_lists)
      lists = List.where(id: @top_list_interlocks.map { |a| a[0] }).group_by(&:id)
      @list_interlocks = [["Other Lists", ""]].concat(@top_list_interlocks.map { |a| l = lists[a[0]].first; [l.name + " (#{interlocks[l.id].count})", l.id] })
    end
  end

  def get_data
    list_entities = ListEntity.includes(entity: [:extension_definitions, :os_categories]).where(list_id: @list.id, is_deleted: false, entity: { is_deleted: false })
    @data = list_entities.map do |le|
      entity = le.entity
      @types = @types.concat(entity.types)
      @industries = @industries.concat(entity.industries)
      interlock_ids = interlocks? ? @top_interlocks.select { |l| l[1].include?(entity.id) }.map { |l| l[0] }.uniq.join(',') : nil
      list_interlock_ids = lists? ? @top_list_interlocks.select { |l| l[1].include?(entity.id) }.map { |l| l[0] }.uniq.join(',') : nil
      list_entity_data(le, interlock_ids, list_interlock_ids)
    end
  end

  def list_entity_data(list_entity, interlock_ids = nil, list_interlock_ids = nil)
    {
      rank: list_entity.rank,
      id: list_entity.entity.id,
      list_entity_id: list_entity.id,
      url: list_entity.entity.legacy_url,
      name: list_entity.entity.name,
      rels_url: relationships_entity_path(list_entity.entity),
      remove_url: remove_entity_list_path(list_entity.list, list_entity_id: list_entity.id),
      blurb: list_entity.entity.blurb,
      types: list_entity.entity.types.join(","),
      industries: list_entity.entity.industries.join(','),    
      context: list_entity.list.custom_field_name.present? ? list_entity.custom_field : list_entity.entity.blurb,
      interlock_ids: interlock_ids,
      list_interlock_ids: list_interlock_ids
     }
  end

  def prepare_options
    @types.uniq!
    @types = [["Type", ""]].concat(ExtensionDefinition.order(:tier).pluck(:display_name).select { |t| @types.include?(t) }.map { |t| [t, t] })
    @industries -= ["Other", "Unknown", "Non-contribution"]
    @industries.uniq!
    @industries.sort!
    @industries = [["Industry", ""]].concat(@industries)
  end

  def ranked?
    @list.is_ranked
  end

  def interlocks?
    @force_interlocks or (@num_links < 5000)
  end

  def lists?
    @entity_ids.count < 500
  end

  def context_field_name
    @list.custom_field_name.present? ? @list.custom_field_name : 'Details'
  end
end