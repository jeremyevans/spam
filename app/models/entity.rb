class Entity < ActiveRecord::Base
  has_many :entries
  @scaffold_fields = %w'name'
  @scaffold_select_order = 'name'
  def scaffold_name
    name[0..30]
  end
end
