module UpdateHelper
  def entity_autocompleter_and_focus
    "new Ajax.EntityAutocompleter('entity_name', 'entity_name_auto_complete', '/update/auto_complete_for_entity_name', {})\ndocument.forms[0].entry_date.focus()".html_safe!
  end
end
