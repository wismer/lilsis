namespace :notes do
	desc "sets new_user_id based on legacy user_id for each Note\n"
	task set_all_new_users: :environment do
		Note.all.each do |note|
			note.set_new_user_id
			note.save
		end
		print "set new_user_id based on legacy user_id for each Note\n"
	end

  desc "normalizes legacy relational fields for each Note"
  task normalize_all: :environment do
  	Note.all.each do |note|
  		note.normalize
  	end
  	print "normalized legacy relational fields for each Note\n"
  end

  desc "sets is_legacy = 1 for all Notes"
  task make_all_legacy: :environment do
  	Note.update_all(is_legacy: true)
	  print "marked all Notes as legacy\n"
  end

  desc "re-renders HTML body based on body_raw for each Note"
  task rerender_all: :environment do
    Note.all.each do |note|
      note.render_body(true) # overrides existing note bodies
    end
    print "re-rendered all Note bodies\n"
  end

  desc "converts new legacy notes"
  task convert_all_new_legacy: :environment do
    Note.convert_all_new_legacy
    print "converted all new legacy Notes to Rails format\n"
  end
end
