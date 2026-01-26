+++
date = '2026-01-24T16:07:44+05:30'
draft = false
tags = ['TIL', 'Go', 'Docker']
title = 'Go build cache key and -trimpath'
+++

---
## Background

I spent the last weekend trying to speed up a CI pipeline which builds a bunch
of docker images for some go services. This pipeline runs on GitHub Actions on
GitHub-hosted runners so there is no persistent storage.

The first thing I did was introduce docker layer caching in the pipeline with
Docker BuildKit's [gha cache backend](https://docs.docker.com/build/cache/backends/#backends)
which "utilizes the GitHub-provided Action's cache." This worked for cache
hits, but every time there was even a small change in a go module, the whole
layer would get invalidated leading to a full build of the module and its
dependencies since there is no go build cache in the new layer.

---

## Mount go build cache from host

I had the idea to warm up go build cache by running the build on the host
machine and then bind mount the cache in the docker build. 

```bash
# Warm up cache on the host machine. I also added an actions/cache step in the
# github action to cache $HOME/.cache/go-build/ so that it can be loaded on
# future runs.
$ go build ./...
```

```dockerfile
RUN --mount=type=bind,from=gobuildcache,target=/root/.cache/go-build,rw \
    go build -o server . 
```

```bash
# mount $HOME/.cache/go-build to share cache
$ docker buildx build \
    --build-context gobuildcache=$HOME/.cache/go-build \
    -t myapp:latest .
...
#10 [stage-0 4/4] RUN --mount=type=bind,rw,from=gobuildcache,target=/root/.cache/go-build go build -v
#10 0.215 github.com/imperfect-fourth/go-build-cache-key/internal/subpkg1
#10 0.215 github.com/imperfect-fourth/go-build-cache-key/pkg/subpkg2
#10 0.227 golang.org/x/sys/unix
#10 0.521 github.com/mattn/go-isatty
#10 0.542 github.com/mattn/go-colorable
#10 0.559 github.com/fatih/color
#10 0.590 github.com/imperfect-fourth/go-build-cache-key
#10 DONE 1.3s
...
```

And... it didn't work. Every package recompiled despite the cache being present.

---
## The Issue

When you build a package, go calculates a cache key using go version, module
name, build flags, etc. And, apart from the contents, it also includes the 
_**absolute**_ path for all the files in the package 
(you can see it in the go source [here](https://cs.opensource.google/go/go/+/master:src/cmd/go/internal/work/exec.go;l=425-427?q=exec.go&ss=go%2Fgo:src%2Fcmd%2Fgo%2Finternal%2F)).
The absolute path for the package in the docker build was /app/<package>,
which doesn't match the path on the host machince where the go build cache was
built. Even for the dependencies, the file paths are prefixed with GOMODCACHE
env var (or the path for the vendor/ directory if the dependencies are
vendored). So, even when I mounted the build cache during the docker build,
go recompiled everything again.

---
## The Fix: -trimpath

go build has a flag `-trimpath` which [according to docs](https://pkg.go.dev/cmd/go#hdr-Compile_packages_and_dependencies):
>   [...] removes all file system paths from the resulting executable.
	Instead of absolute file system paths, the recorded file names
	will begin either a module path@version (when using modules),
	or a plain import path (when using the standard library, or GOPATH).

&nbsp;

The primary purpose of the flag is to remove file system paths from the built
binaries and provide reproducible builds across machines. But, this flag also
removes the file system paths in cache key caclulation which means that the
build cache can also be shared as long as other parameters(i.e. go version,
build flags, etc) remain the same. So, I added the flag while building the
cache on the host machine and also the dockerfile:

```bash
$ go build -trimpath ./...
```

```dockerfile
RUN --mount=type=bind,from=gobuildcache,target=/root/.cache/go-build,rw \
    go build -trimpath -o server . 

...
#7 [context gobuildcache] load from client
#7 transferring gobuildcache: 75.46MB 0.4s done
#7 DONE 0.4s
...
#10 [stage-0 4/4] RUN --mount=type=bind,rw,from=gobuildcache,target=/root/.cache/go-build go build -trimpath -v
#10 DONE 0.3s
...
```

Et voilà. No packages were built and go build ran almost instantaneously. 

---


I used a sample app for demonstration here that anyway builds under 2s, but the 
packages I was dealing with would take several minutes. In the end, after all
the caching I was able to cut down the CI pipeline runtime from 30+ minutes
to 15 minutes. All of the 15 minutes saved came from time saved in go build.
The rest is scaffolding and tests.
