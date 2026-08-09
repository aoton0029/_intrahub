# Netdata

Debianホスト、Dockerコンテナ、NVIDIA GPUのメトリクスを収集し、`http://127.0.0.1:19999`でダッシュボードを提供します。ミニPCではCaddyを通して`http://monitor.aoton.win`から利用します。

GPU監視にはホストのNVIDIA driverとNVIDIA Container Toolkitが必要です。`docker run --rm --gpus all nvidia/cuda:13.0.1-base-ubuntu24.04 nvidia-smi`が成功することを先に確認してください。

ホストとコンテナの情報を収集するため、host PID namespace、`SYS_PTRACE`、`SYS_ADMIN`、Docker socket、`/proc`、`/sys`へアクセスします。ダッシュボードをインターネットへ直接公開しないでください。
