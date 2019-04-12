/// Completes initialisation for Chatterbox
/// This script should be called after chatterbox_init_start() and chatterbox_init_add()
///
/// Once this script has been run, Chatterbox is ready for use!

var _timer = get_timer();

if ( !variable_global_exists("__chatterbox_init_complete" ) )
{
    show_error("Chatterbox:\nchatterbox_init_end() should be called after chatterbox_init_start()\n ", false);
    exit;
}

show_debug_message("Chatterbox: Initialisation started");



var _font_count = ds_map_size(global.__chatterbox_file_data);
var _name = ds_map_find_first(global.__chatterbox_file_data);
repeat(_font_count)
{
    var _font_data = global.__chatterbox_file_data[? _name ];
    show_debug_message("Chatterbox:   Processing file \"" + _name + "\"");
    
    var _filename = _font_data[ __CHATTERBOX_FILE.FILENAME ];
    
    var _buffer = buffer_load(global.__chatterbox_font_directory + _filename);
    var _string = buffer_read(_buffer, buffer_string);
    buffer_delete(_buffer);
    
    var _chatterbox_map = ds_map_create();
    ds_map_add_map(global.__chatterbox_data, _filename, _chatterbox_map);
    
    var _yarn_json = json_decode(_string);
    var _node_list = _yarn_json[? "default" ];
    var _node_count = ds_list_size(_node_list);
    var _title_string = "Chatterbox:     Found " + string(_node_count) + " titles: ";
    var _title_count = 0;
    for(var _node = 0; _node < _node_count; _node++)
    {
        var _node_map = _node_list[| _node];
        var _title = _node_map[? "title" ];
        var _body  = _node_map[? "body"  ];
        
        var _instruction_list = ds_list_create();
        ds_map_add_list(_chatterbox_map, _title, _instruction_list);
        
        
        
        //Debug output that displays all the nodes in a file
        _title_string += "\"" + _title + "\"";
        if (_node < _node_count-1)
        {
            _title_string += ", ";
            _title_count++;
            if (_title_count >= 30)
            {
                show_debug_message(_title_string);
                _title_string = "Chatterbox:     ";
                _title_count = 0;
            }
        }
        
        
        
        //Prepare body string for parsing
        _body = string_replace_all(_body, "\n\r", "\n");
        _body = string_replace_all(_body, "\r\n", "\n");
        _body = string_replace_all(_body, "\r"  , "\n");
        if (__CHATTERBOX_DEBUG)
        {
            if (_node == 0) show_debug_message("Chatterbox:");
            show_debug_message("Chatterbox:     \"" + string(_title) + "\" : \"" + string_replace_all(string(_body), "\n", "\\n") + "\"");
        }
        _body += "\n";
        
        
        
        #region Parse the body text for this node
        
        var _read = 0;
        var _read_prev = 1;
        var _read_char = "";
        var _read_char_prev = "";
        var _string = "";
        var _close_type = __CHATTERBOX_VM_TEXT;
        var _open_type  = __CHATTERBOX_VM_TEXT;
        
        var _fresh_newline = true;
        var _indent      = 0;
        var _indent_prev = 0;
        repeat(string_length(_body))
        {
            _read++;
            _read_char_prev = _read_char;
            _read_char = string_char_at(_body, _read);
            
            _string = "";
            
            if (_read_char == "\n")
            {
                _string = string_copy(_body, _read_prev, _read - _read_prev);
                _read_prev = _read+1;
                
                if (_open_type == __CHATTERBOX_VM_TEXT) _close_type = __CHATTERBOX_VM_TEXT;
                _fresh_newline = true;
            }
            else if (_read_char == _read_char_prev)
            {
                if (_read_char == "[")
                {
                    _string = string_copy(_body, _read_prev, _read - _read_prev - 1);
                    _read_prev = _read+1;
                
                    if (_open_type == __CHATTERBOX_VM_TEXT)
                    {
                        _close_type = __CHATTERBOX_VM_TEXT;
                        _open_type  = __CHATTERBOX_VM_OPTION;
                    }
                }
                else if (_read_char == "]")
                {
                    _string = string_copy(_body, _read_prev, _read - _read_prev - 1);
                    _read_prev = _read+1;
                
                    if (_open_type == __CHATTERBOX_VM_OPTION)
                    {
                        _close_type = __CHATTERBOX_VM_OPTION;
                        _open_type  = __CHATTERBOX_VM_TEXT;
                    }
                }
                else if (_read_char == "<")
                {
                    _string = string_copy(_body, _read_prev, _read - _read_prev - 1);
                    _read_prev = _read+1;
                
                    if (_open_type == __CHATTERBOX_VM_TEXT)
                    {
                        _close_type = __CHATTERBOX_VM_TEXT;
                        _open_type  = __CHATTERBOX_VM_ACTION;
                    }
                }
                else if (_read_char == ">")
                {
                    _string = string_copy(_body, _read_prev, _read - _read_prev - 1);
                    _read_prev = _read+1;
                
                    if (_open_type == __CHATTERBOX_VM_ACTION)
                    {
                        _close_type = __CHATTERBOX_VM_ACTION;
                        _open_type  = __CHATTERBOX_VM_TEXT;
                    }
                }
            }
            
            //If we haven't found a string to handle, or we've found a load of whitespace, do another iteration
            if (_string == "") continue;
            
            //Strip whitespace from both ends of the string
            _string = __chatterbox_remove_whitespace(_string, false);
            if (_string == "") continue;
            _string = __chatterbox_remove_whitespace(_string, true);
            _indent = global.__chatterbox_indent_size;
            if (CHATTERBOX_ROUND_UP_INDENTS) _indent = CHATTERBOX_TAB_INDENT_SIZE*ceil(_indent/CHATTERBOX_TAB_INDENT_SIZE);
            
            switch(_close_type)
            {
                case __CHATTERBOX_VM_TEXT:
                    if (string_copy(_string, 1, 2) == "->")
                    {
                        ds_list_add(_instruction_list, [__CHATTERBOX_VM_SHORTCUT, _indent, __chatterbox_remove_whitespace(string_delete(_string, 1, 2), true)]);
                    }
                    else
                    {
                        ds_list_add(_instruction_list, [__CHATTERBOX_VM_TEXT, _indent, _string]);
                    }
                    
                    if (_read_char != "\n") _fresh_newline = false;
                break;
                
                case __CHATTERBOX_VM_OPTION:
                    var _pos = string_pos("|", _string);
                    if (_pos < 1)
                    {
                        ds_list_add(_instruction_list, [__CHATTERBOX_VM_REDIRECT, _indent, _string]);
                    }
                    else
                    {
                        var _display_text = __chatterbox_remove_whitespace(string_copy(_string, 1, _pos-1), false);
                        var _target_title = __chatterbox_remove_whitespace(string_delete(_string, 1, _pos), true);
                        ds_list_add(_instruction_list, [__CHATTERBOX_VM_OPTION, _indent, _display_text, _target_title]);
                    }
                break;
                
                case __CHATTERBOX_VM_ACTION:
                    if (string_copy(_string, 1, 3) == "if ")
                    {
                        if (_fresh_newline)
                        {
                            ds_list_add(_instruction_list, [__CHATTERBOX_VM_IF, _indent, __chatterbox_remove_whitespace(string_delete(_string, 1, 3), true)]);
                        }
                        else
                        {
                            _indent = _indent_prev;
                            ds_list_insert(_instruction_list, ds_list_size(_instruction_list)-1, [__CHATTERBOX_VM_IF, _indent, _string]);
                            ds_list_add(_instruction_list, [__CHATTERBOX_VM_IF_END, _indent]);
                        }
                    }
                    else if (_string == "endif")
                    {
                        ds_list_add(_instruction_list, [__CHATTERBOX_VM_IF_END, _indent]);
                    }
                    else if (_string == "else")
                    {
                        ds_list_add(_instruction_list, [__CHATTERBOX_VM_ELSE, _indent]);
                    }
                    else if (string_copy(_string, 1, 7) == "elseif ")
                    {
                        ds_list_add(_instruction_list, [__CHATTERBOX_VM_ELSEIF, _indent, __chatterbox_remove_whitespace(string_delete(_string, 1, 7), true)]);
                    }
                    else
                    {
                        ds_list_add(_instruction_list, [__CHATTERBOX_VM_ACTION, _indent, _string]);
                    }
                break;
            }
            
            _indent_prev = _indent;
        }
        
        #endregion
        
        
        
        //Debug output that enumerates all instructions for this node
        if (__CHATTERBOX_DEBUG)
        {
            var _i = 0;
            repeat(ds_list_size(_instruction_list))
            {
                var _array = _instruction_list[| _i];
                _string = "";
                
                var _j = 0;
                repeat(array_length_1d(_array))
                {
                    var _value = _array[_j];
                    if (is_string(_value)) _string += "\"" + _array[_j] + "\", " else _string += string(_array[_j]) + ", ";
                    _j++;
                }
                show_debug_message("Chatterbox:       " + _string);
                
                _i++;
            }
            show_debug_message("Chatterbox:");
        }
    }
    
    //Debug output that displays all the nodes in a file
    show_debug_message(_title_string);
    
    ds_map_destroy(_yarn_json);
}



show_debug_message("Chatterbox: Initialisation complete, took " + string((get_timer() - _timer)/1000) + "ms");
show_debug_message("Chatterbox: Thanks for using Chatterbox!");

global.__chatterbox_init_complete = true;