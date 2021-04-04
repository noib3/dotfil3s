{ secrets-directory }:

''
  #!/usr/bin/env bash

  function notify_commit() {
    terminal-notifier \
      -title "Calcurse's post-save hook" \
      -subtitle "Automatic commit script" \
      -message "Pushing changes to Github..." \
      -appIcon "$(dirname $0)/calendar-icon.png"
  }

  function commit_new_entries() {
    cd "${secrets-directory}/calcurse"
    git add .
    git commit -m \
      "$(date +%4Y-%b-%d@%T) Commit by post-save script"
    git push origin master
  }

  notify_commit
  commit_new_entries
''