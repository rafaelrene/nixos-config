on run argv
    set outcome to "Succeeded"
    if item 2 of argv is "error" then set outcome to "Failed"
    display notification (item 3 of argv) with title (item 1 of argv) subtitle outcome
end run
