  $: << '/data/code/forme/lib'
  $: << '/data/code/autoforme/lib'
  require 'autoforme'
  Forme.register_config(:mine, :base=>:default, :labeler=>:explicit, :wrapper=>:div)
  Forme.default_config = :mine
