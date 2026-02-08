ubuntu@ip-10-0-167-200:~/gitlab$ pm2 describe 0
 Describing process with id 0 - name detoxnearme
┌───────────────────┬─────────────────────────────────────────────────┐
│ status            │ online                                          │
│ name              │ detoxnearme                                     │
│ namespace         │ default                                         │
│ version           │ 0.39.3                                          │
│ restarts          │ 0                                               │
│ uptime            │ 19D                                             │
│ script path       │ /home/ubuntu/.nvm/versions/node/v20.5.1/bin/npm │
│ script args       │ run start                                       │
│ error log path    │ /home/ubuntu/.pm2/logs/detoxnearme-error.log    │
│ out log path      │ /home/ubuntu/.pm2/logs/detoxnearme-out.log      │
│ pid path          │ /home/ubuntu/.pm2/pids/detoxnearme-0.pid        │
│ interpreter       │ node                                            │
│ interpreter args  │ N/A                                             │
│ script id         │ 0                                               │
│ exec cwd          │ /home/ubuntu/gitlab                             │
│ exec mode         │ fork_mode                                       │
│ node.js version   │ 20.5.1                                          │
│ node env          │ N/A                                             │
│ watch & reload    │ ✘                                               │
│ unstable restarts │ 0                                               │
│ created at        │ 2023-11-28T00:12:37.539Z                        │
└───────────────────┴─────────────────────────────────────────────────┘
 Revision control metadata
┌──────────────────┬──────────────────────────────────────────┐
│ revision control │ git                                      │
│ remote url       │ <https://github.com/nvm-sh/nvm.git>        │
│ repository root  │ /home/ubuntu/.nvm                        │
│ last update      │ 2023-11-28T00:12:37.842Z                 │
│ revision         │ 552db40622bb7a82d9c6d67d2d6bcf3694b47e30 │
│ comment          │ v0.39.3                                  │
│ branch           │ HEAD                                     │
└──────────────────┴──────────────────────────────────────────┘
 Actions available
┌────────────────────────┐
│ km:heapdump            │
│ km:cpu:profiling:start │
│ km:cpu:profiling:stop  │
│ km:heap:sampling:start │
│ km:heap:sampling:stop  │
└────────────────────────┘
 Trigger via: pm2 trigger detoxnearme <action_name>

 Code metrics value
┌────────────────────────┬───────────┐
│ Used Heap Size         │ 18.81 MiB │
│ Heap Usage             │ 92.26 %   │
│ Heap Size              │ 20.39 MiB │
│ Event Loop Latency p95 │ 1.10 ms   │
│ Event Loop Latency     │ 0.42 ms   │
│ Active handles         │ 5         │
│ Active requests        │ 0         │
└────────────────────────┴───────────┘
 Divergent env variables from local env
┌────────────────┬──────────────────────────────────────┐
│ NVM_INC        │ /home/ubuntu/.nvm/versions/node/v20. │
│ SSH_CONNECTION │ 162.252.100.250 58539 10.0.167.200 2 │
│ TERM           │ xterm                                │
│ XDG_SESSION_ID │ 1                                    │
│ SSH_CLIENT     │ 162.252.100.250 58539 22             │
│ PATH           │ /home/ubuntu/.nvm/versions/node/v20. │
│ NVM_BIN        │ /home/ubuntu/.nvm/versions/node/v20. │
│ _              │ /home/ubuntu/.nvm/versions/node/v20. │
