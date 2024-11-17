### Contents 
<!--toc:start-->
- [WHY?](#why)
- [Features](#features)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
<!--toc:end-->

---

A neovim plugin written in pure `lua` for integration with [Todoist](www.todoist.com).

### WHY?

- Other neovim plugins do not have full functionality for integrating with todist 

    > Here plugins may use the REST api method for integrating with todoist documented [here](https://developer.todoist.com/rest/v2/#overview)
    > The REST api does not have the capabilities to add reminders for example

- Other plugins are outdated 
    
    > Written in `vimscript` or combining with other languages e.g. `python`, `javascript`

- Other plugins don't allow for much if any configuration
    
    > Not able to customise the rending of colours in the ui

### Features

1. Full integration with todoist (all features for adding tasks are implemented, including todoist pro features)
2. Customisation of the ui colours used when previewing tasks 
3. Easy to set up (no additional dependencies)
4. Add/ delete/ complete tasks fast and efficiently 

### Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'adam-coates/todoist.nvim',
  config = function()
    require('todoist').setup({
      -- Optional config
      auto_refresh_interval = 30000, -- 30 seconds
      highlight = {
        priority1 = "#ff0000",
        priority2 = "#ff8c00",
        priority3 = "#0087ff",
      }
    })
  end
}
```

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'adam-coates/todoist.nvim',
  config = function()
    require('todoist').setup()
  end
}
```

### Configuration

First, set your Todoist API token in your environment:

```bash
export TODOIST_API_KEY='your-api-token-here'
```

> [!NOTE]
> It is advisable to use a password management system e.g. pass 


```bash
$ pass insert Todoist/API
Enter password for Todoist/API: XXXXXXXXX
```
```bash
export TODOIST_API_KEY="$(pass Todoist/API)"
```


### Usage

1. Open Todoist view:
   ```
   :Todoist
   ```

2. Key mappings in Todoist buffer:
   - `<Enter>` on empty line: Add new task
   - `c`: Toggle task completion
   - `dd`: Delete task
   - `r`: Refresh tasks manually

