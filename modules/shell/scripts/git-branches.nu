use git.nu git-output

# Switch this checkout, including branches available only on a remote.
def main [branch?: string] {
    let selected = if $branch != null {
        $branch
    } else {
        let current = (^git symbolic-ref --quiet --short HEAD | complete).stdout | str trim
        let branches = (
      git-output $env.PWD branch --all '--format=%(refname:short)%09%(symref)'
      | lines
      | split column "\t" name target
      | where {|row| $row.target == "" and $row.name != $current }
      | get name
      | str replace --regex '^origin/' ''
      | uniq
      | str join (char nl)
    )
        let result = $branches | ^fzf | complete
        if $result.exit_code in [1 130] { return }
        if $result.exit_code != 0 {
            print --stderr $result.stderr
            exit $result.exit_code
        }
        $result.stdout | str trim --right --char "\n"
    }
    if $selected == "" { return }
    exec git checkout $selected
}
