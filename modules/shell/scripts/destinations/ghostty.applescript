use framework "Foundation"
use scripting additions

on run argv
    set operation to item 1 of argv
    if operation is "list" then
        if application "Ghostty" is not running then return "[]"
        set rows to current application's NSMutableArray's array()
        tell application "Ghostty"
            -- Ghostty returns windows front to back, preserving MRU selection.
            repeat with w in windows
                repeat with t in terminals of w
                    set row to current application's NSMutableDictionary's dictionary()
                    row's setObject:(id of t) forKey:"id"
                    row's setObject:(working directory of t) forKey:"path"
                    row's setObject:(name of t) forKey:"title"
                    rows's addObject:row
                end repeat
            end repeat
        end tell
        set jsonData to current application's NSJSONSerialization's dataWithJSONObject:rows options:0 |error|:(missing value)
        set jsonString to current application's NSString's alloc()
        return (jsonString's initWithData:jsonData encoding:(current application's NSUTF8StringEncoding)) as text
    else if operation is "focus" then
        set terminalID to item 2 of argv
        tell application "Ghostty"
            focus terminal id terminalID
            activate
        end tell
    else if operation is "new" then
        set destinationKind to item 2 of argv
        set destinationPath to item 3 of argv
        set sshExecutable to item 4 of argv
        tell application "Ghostty"
            launch
            set surfaceConfig to new surface configuration
            if destinationKind is "ssh" then
                set command of surfaceConfig to (quoted form of sshExecutable) & " " & (quoted form of destinationPath)
            else
                set initial working directory of surfaceConfig to destinationPath
            end if
            new window with configuration surfaceConfig
            activate
        end tell
    else
        error "Unknown Ghostty operation"
    end if
end run
