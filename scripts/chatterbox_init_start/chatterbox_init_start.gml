/// Starts initialisation for Chatterbox
/// This script should be called before chatterbox_init_add() and chatterbox_init_end()
///
/// @param fontDirectory     Directory to look in (relative to game_save_id) for Yarn .json files
///
/// Initialisation is only fully complete once chatterbox_init_end() is called

#region Internal Macro Definitions

#macro __CHATTERBOX_VERSION  "0.0.7"
#macro __CHATTERBOX_DATE     "2019/04/15"

enum __CHATTERBOX_FILE
{
    FILENAME, //0
    NAME,     //1
    __SIZE    //2
}

enum __CHATTERBOX_INSTRUCTION
{
    TYPE,    //0
    INDENT,  //1
    CONTENT, //2
    __SIZE   //3
}

enum __CHATTERBOX
{
    FILENAME,    //0
    TITLE,       //1
    SUSPENDED,   //2
    VARIABLES,   //3
    CHILD_LIST,  //4
    __SIZE       //5
}

enum __CHATTERBOX_CHILD
{
    STRING,            //0
    TYPE,              //1
    INSTRUCTION_START, //2
    INSTRUCTION_END,   //3
    __SIZE             //4
}

#macro __CHATTERBOX_SCOPE_INVALID     -1
#macro __CHATTERBOX_VARIABLE_INVALID  "__chatterbox_variable_error"
#macro __CHATTERBOX_VARIABLE_MAP   (CHATTERBOX_INTERNAL_VARIABLE_MAP_SCOPE == CHATTERBOX_SCOPE_GML_LOCAL)? _chatterbox[| __CHATTERBOX.VARIABLES ] : global.__chatterbox_variables

#macro __CHATTERBOX_VM_UNKNOWN         "UNKNOWN"
#macro __CHATTERBOX_VM_WAIT            "WAIT"
#macro __CHATTERBOX_VM_TEXT            "TEXT"
#macro __CHATTERBOX_VM_SHORTCUT        "SHORTCUT"
#macro __CHATTERBOX_VM_OPTION          "OPTION"
#macro __CHATTERBOX_VM_REDIRECT        "REDIRECT"
#macro __CHATTERBOX_VM_GENERIC_ACTION  "ACTION"
#macro __CHATTERBOX_VM_IF              "IF"
#macro __CHATTERBOX_VM_ELSE            "ELSE"
#macro __CHATTERBOX_VM_ELSEIF          "ELSE IF"
#macro __CHATTERBOX_VM_IF_END          "END"
#macro __CHATTERBOX_VM_SET             "SET"
#macro __CHATTERBOX_VM_STOP            "STOP"
#macro __CHATTERBOX_VM_CUSTOM_ACTION   "CUSTOM"
#macro __CHATTERBOX_VM_SUSPEND         "SUSPEND"

#macro __CHATTERBOX_ON_MOBILE  ((os_type == os_ios) || (os_type == os_android))

#endregion

if ( variable_global_exists("__chatterbox_init_complete") )
{
    show_error("Chatterbox:\nchatterbox_init_start() should not be called twice!\n ", false);
    exit;
}

show_debug_message("Chatterbox: Welcome to Chatterbox by @jujuadams! This is version " + __CHATTERBOX_VERSION + ", " + __CHATTERBOX_DATE);

var _font_directory = argument0;

if (__CHATTERBOX_ON_MOBILE)
{
    if (_font_directory != "")
    {
        show_debug_message("Chatterbox: Included Files work a bit strangely on iOS and Android. Please use an empty string for the font directory and place Yarn .json files in the root of Included Files.");
        show_error("Chatterbox:\nGameMaker's Included Files work a bit strangely on iOS and Android.\nPlease use an empty string for the font directory and place Yarn .json files in the root of Included Files.\n ", true);
        exit;
    }
}
else
{
    //Fix the font directory name if it's weird
    var _char = string_char_at(_font_directory, string_length(_font_directory));
    if (_char != "\\") && (_char != "/") _font_directory += "\\";
}

//Check if the directory exists
if ( !directory_exists(_font_directory) )
{
    show_debug_message("Chatterbox: WARNING! Font directory \"" + string(_font_directory) + "\" could not be found in \"" + game_save_id + "\"!");
}

//Declare global variables
global.__chatterbox_font_directory    = _font_directory;
global.__chatterbox_file_data         = ds_map_create();
global.__chatterbox_goto              = ds_map_create();
global.__chatterbox_vm                = ds_list_create();
global.__chatterbox_init_complete     = false;
global.__chatterbox_default_file      = "";
global.__chatterbox_indent_size       = 0;
global.__chatterbox_scope             = __CHATTERBOX_SCOPE_INVALID;
global.__chatterbox_variable_name     = __CHATTERBOX_VARIABLE_INVALID;
global.__chatterbox_variables         = ds_map_create();
global.__chatterbox_actions           = ds_map_create();
global.__chatterbox_permitted_scripts = ds_map_create();

//Big ol' list of operator dipthongs
global.__chatterbox_op_list        = ds_list_create();
global.__chatterbox_op_list[|  0 ] = "("; 
global.__chatterbox_op_list[|  1 ] = "!"; 
global.__chatterbox_op_list[|  2 ] = "/=";
global.__chatterbox_op_list[|  3 ] = "/"; 
global.__chatterbox_op_list[|  4 ] = "*=";
global.__chatterbox_op_list[|  5 ] = "*"; 
global.__chatterbox_op_list[|  6 ] = "+"; 
global.__chatterbox_op_list[|  7 ] = "+=";
global.__chatterbox_op_list[|  8 ] = "-"; 
global.__chatterbox_op_list[|  9 ] = "-";  global.__chatterbox_negative_op_index = 9;
global.__chatterbox_op_list[| 10 ] = "-=";
global.__chatterbox_op_list[| 11 ] = "||";
global.__chatterbox_op_list[| 12 ] = "&&";
global.__chatterbox_op_list[| 13 ] = ">=";
global.__chatterbox_op_list[| 14 ] = "<=";
global.__chatterbox_op_list[| 15 ] = ">"; 
global.__chatterbox_op_list[| 16 ] = "<"; 
global.__chatterbox_op_list[| 17 ] = "!=";
global.__chatterbox_op_list[| 18 ] = "==";
global.__chatterbox_op_list[| 19 ] = "=";
global.__chatterbox_op_count = ds_list_size(global.__chatterbox_op_list);