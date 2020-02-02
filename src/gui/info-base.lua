-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
-- BASE INFO GUI

-- dependencies
local event = require('lualib/event')
local gui = require('lualib/gui')

-- self object
local self = {}

-- GUI templates
gui.add_templates{
  close_button = {type='sprite-button', style='close_button', sprite='utility/close_white', hovered_sprite='utility/close_black',
    clicked_sprite='utility/close_black', handlers='close_button', mouse_button_filter={'left'}},
  pushers = {
    horizontal = {type='empty-widget', style={horizontally_stretchable=true}},
    vertical = {type='empty-widget', style={vertically_stretchable=true}}
  }
}

-- info pages
local pages = {}
for n,_ in pairs(info_guis) do
  pages[n] = require('gui/info-pages/'..n)
end

-- locals
local string_lower = string.lower
local table_insert = table.insert
local table_remove = table.remove

-- -----------------------------------------------------------------------------
-- HANDLERS

-- we must define it like this so memmbers can access other members
local handlers = {}
handlers = {
  close_button = {
    on_gui_click = function(e)
      self.close(game.get_player(e.player_index), global.players[e.player_index])
    end
  },
  nav_backward_button = {
    on_gui_click = function(e)
      local player_table = global.players[e.player_index]
      local session_history = player_table.history.session
      local back_obj = session_history[session_history.position+1]
      if back_obj.source then
        self.close(game.get_player(e.player_index), player_table)
        event.raise(reopen_source_event, {player_index=e.player_index, source=back_obj.source})
      else
        session_history.position = session_history.position + 1
        -- update content
        self.update_content(game.get_player(e.player_index), player_table, back_obj.category, back_obj.name, nil, true)
      end
    end
  },
  window = {
    on_gui_closed = function(e)
      self.close(game.get_player(e.player_index), global.players[e.player_index])
    end
  }
}

gui.add_handlers('info_base', handlers)

-- -----------------------------------------------------------------------------
-- GUI MANAGEMENT

function self.open(player, player_table, category, name, source)
  -- gui structure
  local gui_data = gui.create(player.gui.screen, 'info_base', player.index,
    {type='frame', name='rb_info_window', style='dialog_frame', direction='vertical', handlers='window', save_as=true, children={
      -- titlebar
      {type='flow', style='rb_titlebar_flow', direction='horizontal', children={
        {type='sprite-button', style='close_button', sprite='rb_nav_backward', hovered_sprite='rb_nav_backward_dark', clicked_sprite='rb_nav_backward_dark',
          mouse_button_filters={'left'}, handlers='nav_backward_button', save_as=true},
        {type='label', style={name='frame_title', left_padding=6}, save_as='window_title'},
        {type='empty-widget', style='rb_titlebar_draggable_space', save_as='drag_handle'},
        {template='close_button'}
      }},
      {type='frame', style='window_content_frame_packed', direction='vertical', children={
        -- toolbar
        {type='frame', style='subheader_frame', direction='horizontal', children={
          {type='sprite', style='rb_object_icon', save_as='object_icon'},
          {type='label', style={name='subheader_caption_label', left_padding=0}, save_as='object_name'},
          {template='pushers.horizontal'}
        }},
        -- content container
        {type='flow', style={padding=8}, save_as='content_container'}
      }}
    }}
  )

  -- drag handle
  gui_data.drag_handle.drag_target = gui_data.window

  -- opened
  player.opened = gui_data.window

  -- add to global
  player_table.gui.info = {base=gui_data}

  -- set initial content
  self.update_contents(player, player_table, category, name, source)
end

function self.close(player, player_table)
  local gui_data = player_table.gui
  -- destroy content / deregister handlers
  -- pages[gui_data.info.category].destroy(player, gui_data.info.base.content_scrollpane)
  -- destroy base
  gui.destroy(gui_data.info.base.window, 'info_base', player.index)
  -- remove data from global
  gui_data.info = nil
end

function self.update_contents(player, player_table, category, name, source, nav_button)
  local gui_data = player_table.gui.info
  local base_elems = gui_data.base
  local dictionary = player_table.dictionary
  local object_data = global.recipe_book[category][name]

  -- update search history
  if not nav_button then
    table_insert(player_table.history.overall, 1, {category=category, name=name})
  end
  local session_history = player_table.history.session
  if source then
    -- reset session history
    player_table.history.session = {position=1, [1]={category=category, name=name}, [2]={source=source}}
    session_history = player_table.history.session
  elseif not nav_button then
    -- modify session history
    if session_history.position > 1 then
      for i=1,session_history.position - 1 do
        table_remove(session_history, 1)
      end
      session_history.position = 1
    end
    table_insert(session_history, 1, {category=category, name=name})
  end

  -- update titlebar
  local back_button = base_elems.nav_backward_button
  local back_obj = session_history[session_history.position+1]
  if back_obj.source then
    back_button.tooltip = {'rb-gui.back-to', {'rb-remote.source-'..back_obj.source}}
  else
    back_button.tooltip = {'rb-gui.back-to', string_lower(dictionary[back_obj.category].translations[back_obj.name] or back_obj.name)}
  end
  base_elems.window_title.caption = {'rb-gui.'..category..'-upper'}

  -- update object name
  base_elems.object_icon.sprite = object_data.sprite_class..'/'..name
  base_elems.object_name.caption = object_data.prototype.localised_name

  -- update main content
  local content_container = base_elems.content_container
  if #content_container.children > 0 then
    -- destroy previous content
    pages[gui_data.category].destroy(player, content_container)
  end
  -- build new content
  gui_data.page = pages[category].create(player, player_table, content_container, name)

  -- center window
  base_elems.window.force_auto_center()

  -- update global data
  gui_data.category = category
  gui_data.name = name
end

function self.open_or_update(player, player_table, category, name, source)
  -- check for pre-existing window
  if player_table.gui.info then
    self.update_contents(player, player_table, category, name, source)
  else
    self.open(player, player_table, category, name, source)
  end
end

-- -----------------------------------------------------------------------------

return self