-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
-- SEARCH GUI

-- dependencies
local event = require('__RaiLuaLib__.lualib.event')
local gui = require('__RaiLuaLib__.lualib.gui')

-- self object
local self = {}

-- locals
local string_lower = string.lower
local string_match = string.match

-- utilities
local category_by_index = {'crafter', 'material', 'recipe'}
local category_to_index = {crafter=1, material=2, recipe=3}

-- -----------------------------------------------------------------------------
-- HANDLERS

-- we must define it like this so members can access other members
local handlers = {}
handlers = {
  close_button = {
    on_gui_click = function(e)
      self.close(game.get_player(e.player_index), global.players[e.player_index])
    end
  },
  search_textfield = {
    on_gui_click = function(e)
      local player_table = global.players[e.player_index]
      local gui_data = player_table.gui.search
      -- reset GUI state
      gui_data.results_listbox.selected_index = 0
      gui_data.state = 'search'
      gui_data.search_textfield.focus()
      game.get_player(e.player_index).opened = gui_data.search_textfield
    end,
    on_gui_closed = function(e)
      local player_table = global.players[e.player_index]
      if player_table.gui.search.state ~= 'select_result' then
        self.close(game.get_player(e.player_index), player_table)
      end
    end,
    on_gui_confirmed = function(e)
      local player_table = global.players[e.player_index]
      local gui_data = player_table.gui.search
      local results_listbox = gui_data.results_listbox
      -- don't do anything if the listbox is empty
      if #results_listbox.items == 0 then return end
      -- set initial selected index
      results_listbox.selected_index = 1
      -- set GUI state
      gui_data.state = 'select_result'
      game.get_player(e.player_index).opened = gui_data.results_listbox
      results_listbox.focus()
      -- register navigation confirmation handler
      gui.register_handlers('search', 'results_nav', {player_index=e.player_index})
    end,
    on_gui_text_changed = function(e)
      local player_table = global.players[e.player_index]
      local gui_data = player_table.gui.search
      local show_hidden = player_table.settings.show_hidden
      local query = string_lower(e.text)
      local category = gui_data.category
      local objects = global.recipe_book[category]
      local dictionary = player_table.dictionary[category]
      local lookup_lower = dictionary.lookup_lower
      local sorted_translations = dictionary.sorted_translations
      local translations = dictionary.translations
      local results_listbox = gui_data.results_listbox
      local skip_matching = query == ''
      local items = {}
      local i = 0
      for i1=1,#sorted_translations do
        local translation = sorted_translations[i1]
        if skip_matching or string_match(translation, query) then
          local names = lookup_lower[translation]
          if names then
            for i2=1,#names do
              local name = names[i2]
              local t = objects[name]
              -- check conditions
              if (show_hidden or not t.hidden) then
                local caption = '[img='..t.sprite_class..'/'..name..']  '..translations[name] -- get the non-lowercase version
                i = i + 1
                items[i] = caption
              end
            end
          end
        end
      end
      results_listbox.items = items
      if e.selected_index then
        results_listbox.scroll_to_item(e.selected_index)
      end
    end
  },
  results_listbox = {
    on_gui_closed = function(e)
      handlers.search_textfield.on_gui_click(e)
    end,
    on_gui_selection_state_changed = function(e)
      local player_table = global.players[e.player_index]
      local gui_data = player_table.gui.search
      if e.keyboard_confirm or gui_data.state ~= 'select_result' then
        local _,_,object_name = e.element.get_item(e.element.selected_index):find('^.*/(.*)%].*$')
        event.raise(open_gui_event, {player_index=e.player_index, gui_type=gui_data.category, object_name=object_name, source_data={mod_name='RecipeBook',
          gui_name='search', category=gui_data.category, query=gui_data.search_textfield.text, selected_index=e.element.selected_index}})
        if e.keyboard_confirm then
          self.close(game.get_player(e.player_index), player_table)
        end
      end
    end
  },
  category_dropdown = {
    on_gui_selection_state_changed = function(e)
      local player_table = global.players[e.player_index]
      local gui_data = player_table.gui.search
      -- update GUI state
      gui_data.category = category_by_index[e.element.selected_index]
      if gui_data.state == 'search' then
        gui_data.search_textfield.focus()
        gui_data.search_textfield.text = ''
        handlers.search_textfield.on_gui_text_changed{player_index=e.player_index, text=''}
      else
        game.get_player(e.player_index).opened = gui_data.search_textfield
      end
    end
  },
  results_nav = {
    ['rb-results-nav-confirm'] = function(e)
      e.element = global.players[e.player_index].gui.search.results_listbox
      e.keyboard_confirm = true
      handlers.results_listbox.on_gui_selection_state_changed(e)
    end
  }
}

-- add to GUI module
gui.add_handlers('search', handlers)

-- -----------------------------------------------------------------------------
-- GUI MANAGEMENT

function self.open(player, player_table, options)
  options = options or {}
  local category = options.category or player_table.settings.default_category
  -- create GUI structure
  local gui_data = gui.build(player.gui.screen, {
    {type='frame', name='rb_search_window', style='dialog_frame', direction='vertical', save_as='window', children={
      -- titlebar
      {type='flow', style='rb_titlebar_flow', children={
        {type='label', style='frame_title', caption={'mod-name.RecipeBook'}},
        {type='empty-widget', style='rb_titlebar_draggable_space', save_as='drag_handle'},
        {template='close_button'}
      }},
      {type='frame', style='window_content_frame_packed', direction='vertical', children={
        -- toolbar
        {type='frame', style='subheader_frame', children={
          {type='label', style='subheader_caption_label', caption={'rb-gui.search-by'}},
          {template='pushers.horizontal'},
          {type='drop-down', items={{'rb-gui.crafter'}, {'rb-gui.material'}, {'rb-gui.recipe'}}, selected_index=category_to_index[category],
            handlers='category_dropdown', save_as=true}
        }},
        -- search bar
        {type='textfield', style_mods={width=225, margin=8, bottom_margin=0}, clear_and_focus_on_right_click=true, handlers='search_textfield', save_as=true},
        -- results listbox
        {type='frame', style='rb_search_results_listbox_frame', style_mods={margin=8}, children={
          {type='list-box', style='rb_listbox_for_keyboard_nav', handlers='results_listbox', save_as=true}
        }}
      }}
    }}
  }, 'search', player.index)
  -- screen data
  gui_data.drag_handle.drag_target = gui_data.window
  gui_data.window.force_auto_center()

  -- gui state
  gui_data.state = 'search'
  gui_data.category = category
  player.opened = gui_data.search_textfield
  gui_data.search_textfield.focus()
  if options.query then
    gui_data.search_textfield.text = options.query
  end

  -- add to global
  player_table.gui.search = gui_data

  -- populate initial results
  handlers.search_textfield.on_gui_text_changed{player_index=player.index, text=options.query or '', selected_index=options.selected_index}
end

function self.close(player, player_table)
  gui.deregister_all('search', player.index)
  player_table.gui.search.window.destroy()
  player_table.gui.search = nil
end

function self.toggle(player, player_table, options)
  local search_window = player.gui.screen.rb_search_window
  if search_window then
    self.close(player, player_table)
  else
    -- check if we actually CAN open the GUI
    if player_table.flags.can_open_gui then
      self.open(player, player_table, options)
    else
      -- set flag and tell the player that they cannot open it
      player_table.flags.tried_to_open_gui = true
      player.print{'rb-message.translation-not-finished'}
    end
  end
end

-- -----------------------------------------------------------------------------

return self