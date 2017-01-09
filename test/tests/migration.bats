# source docker helpers
. util/docker.sh

# source mist helpers
. util/mist.sh

@test "Start Mist Container" {
  start_mist
}

@test "Start Old Container" {
  start_container "test-migrate-old" "192.168.0.2"
}

@test "Configure Old Logvac" {
  # Run Hook
  run run_hook "test-migrate-old" "configure" "$(payload configure)"
  [ "$status" -eq 0 ]
}

@test "Start Logvac On Old" {
  run run_hook "test-migrate-old" "start" "$(payload start)"
  [ "$status" -eq 0 ]
}

@test "Insert Log Data" {
  # wait for a few seconds...
  sleep 3

  run docker exec "test-migrate-old" bash -c "curl -k https://127.0.0.1:6361/logs -i -H \"X-USER-TOKEN: 123\" -d '{\"id\":\"log-test\",\"type\":\"test\",\"message\":\"my first log\"}' 2> /dev/null"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "Start New Container" {
  start_container "test-migrate-new" "192.168.0.4"
}

@test "Configure New Logvac" {
  run run_hook "test-migrate-new" "configure" "$(payload configure-new)"
  [ "$status" -eq 0 ]
}

@test "Prepare New Import" {
  run run_hook "test-migrate-new" "import-prep" "$(payload import-prep)"
  [ "$status" -eq 0 ]
}

@test "Export Live Data" {
  run run_hook "test-migrate-old" "export-live" "$(payload export-live)"
  echo "$output"
  [ "$status" -eq 0 ]

  run docker exec "test-migrate-new" bash -c "[[ ! -d /root/var ]]"
  [ "$status" -eq 0 ]
}

@test "Stop Old Logvac Service" {
  run run_hook "test-migrate-old" "stop" "$(payload stop)"
  [ "$status" -eq 0 ]
}

@test "Export Final Data" {
  run run_hook "test-migrate-old" "export-final" "$(payload export-final)"
  echo "$output"
  [ "$status" -eq 0 ]

  run docker exec "test-migrate-new" bash -c "[[ ! -d /root/var ]]"
  [ "$status" -eq 0 ]
}

@test "Clean After Import" {
  run run_hook "test-migrate-new" "import-clean" "$(payload import-clean)"
  [ "$status" -eq 0 ]
}

@test "Start New Logvac Service" {
  run run_hook "test-migrate-new" "start" "$(payload start)"
  [ "$status" -eq 0 ]
}

@test "Verify Data Transfered" {
  # wait for a few seconds...
  sleep 3
  
  run docker exec "test-migrate-new" bash -c "curl -k -i -H \"X-USER-TOKEN: 123\" \"https://127.0.0.1:6361/logs?type=test\" 2> /dev/null | grep log-test"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "Stop Old Container" {
  stop_container "test-migrate-old"
}

@test "Stop New Container" {
  stop_container "test-migrate-new"
}

@test "Stop Mist Container" {
  stop_mist
}
