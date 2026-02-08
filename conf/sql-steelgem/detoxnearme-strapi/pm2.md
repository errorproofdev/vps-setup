# PM2 Process Manager

``` bash
┌────┬────────────────────┬──────────┬──────┬───────────┬──────────┬──────────┐
│ id │ name               │ mode     │ ↺    │ status    │ cpu      │ memory   │
├────┼────────────────────┼──────────┼──────┼───────────┼──────────┼──────────┤
│ 0  │ strapi             │ fork     │ 10   │ online    │ 0%       │ 42.0mb   │
└────┴────────────────────┴──────────┴──────┴───────────┴──────────┴──────────┘
ubuntu@ip-10-0-163-243:~/gitlab$ pm2 describe 0
 Describing process with id 0 - name strapi
┌───────────────────┬──────────────────────────────────────────────────┐
│ status            │ online                                           │
│ name              │ strapi                                           │
│ namespace         │ default                                          │
│ version           │ 0.39.3                                           │
│ restarts          │ 10                                               │
│ uptime            │ 24M                                              │
│ script path       │ /home/ubuntu/.nvm/versions/node/v18.17.0/bin/npm │
│ script args       │ start                                            │
│ error log path    │ /home/ubuntu/.pm2/logs/strapi-error.log          │
│ out log path      │ /home/ubuntu/.pm2/logs/strapi-out.log            │
│ pid path          │ /home/ubuntu/.pm2/pids/strapi-0.pid              │
│ interpreter       │ node                                             │
│ interpreter args  │ N/A                                              │
│ script id         │ 0                                                │
│ exec cwd          │ /home/ubuntu/gitlab                              │
│ exec mode         │ fork_mode                                        │
│ node.js version   │ 18.17.0                                          │
│ node env          │ N/A                                              │
│ watch & reload    │ ✘                                                │
│ unstable restarts │ 0                                                │
│ created at        │ 2023-11-13T22:29:52.481Z                         │
└───────────────────┴──────────────────────────────────────────────────┘
 Revision control metadata
┌──────────────────┬──────────────────────────────────────────┐
│ revision control │ git                                      │
│ remote url       │ <https://github.com/nvm-sh/nvm.git>        │
│ repository root  │ /home/ubuntu/.nvm                        │
│ last update      │ 2024-02-01T06:13:35.175Z                 │
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
 Trigger via: pm2 trigger strapi <action_name>

 Code metrics value
┌────────────────────────┬───────────┐
│ Used Heap Size         │ 17.81 MiB │
│ Heap Usage             │ 80.48 %   │
│ Heap Size              │ 22.13 MiB │
│ Event Loop Latency p95 │ 1.03 ms   │
│ Event Loop Latency     │ 0.38 ms   │
│ Active handles         │ 4         │
│ Active requests        │ 0         │
└────────────────────────┴───────────┘
 Divergent env variables from local env
┌────────────────┬────────────────────────┐
│ SSH_CONNECTION │ 162.252.100.250 58817  │
│ TERM           │ xterm                  │
│ XDG_SESSION_ID │ 298                    │
│ SSH_CLIENT     │ 162.252.100.250 58817  │
└────────────────┴────────────────────────┘

 Add your own code metrics: <http://bit.ly/code-metrics>
 Use `pm2 logs strapi [--lines 1000]` to display logs
 Use `pm2 env 0` to display environment variables
 Use `pm2 monit` to monitor CPU and Memory usage strapi
```
