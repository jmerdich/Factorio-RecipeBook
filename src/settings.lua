data:extend{
  {
    type = 'bool-setting',
    name = 'rb-show-mod-gui-button',
    setting_type = 'runtime-per-user',
    default_value = true,
    order = 'a'
  },
  {
    type = 'bool-setting',
    name = 'rb-open-fluid-hotkey',
    setting_type = 'runtime-per-user',
    default_value = true,
    order = 'b'
  },
  {
    type = 'bool-setting',
    name = 'rb-show-hidden-objects',
    setting_type = 'runtime-per-user',
    default_value = false,
    order = 'c'
  },
  {
    type = 'string-setting',
    name = 'rb-default-search-category',
    setting_type = 'runtime-per-user',
    default_value = 'material',
    allowed_values = {'crafter', 'material', 'recipe'},
    order = 'd'
  }
}