# Deployment with ECS

Generic resources to script ECS deployments.

# Set Up

  This is all from within the application you want to deploy

  * Add this repository as a git submodule, usually at `config/deploy`

    git submodule add -b production git@github.com:greenriver/ecs-deploy-public.git config/deploy
    git submodule init

  * Make a folder called config/docker_assets

    ```
    mkdir -p config/docker_assets
    ```

  * Symlink workflow directory

    ```
    mkdir -p .github/workflows

    cp config/deploy/.github/workflows/ecs.yml .github/workflows/ecs.yml
    ```

  * Symlink binaries

    ```
    cd bin
    ln -s ../config/deploy/bin/bootstrap_databases .
    ln -s ../config/deploy/bin/clear_cache
    ln -s ../config/deploy/bin/deploy
    ln -s ../config/deploy/bin/list
    ln -s ../config/deploy/bin/list_domains
    ln -s ../config/deploy/bin/mark_spot_instances
    ln -s ../config/deploy/bin/migrate
    ln -s ../config/deploy/bin/only_web_deploy
    ln -s ../config/deploy/bin/poll_state
    ln -s ../config/deploy/bin/cssh
    ln -s ../config/deploy/bin/tail_logs
    ln -s ../config/deploy/bin/test_build
    ln -s ../config/deploy/bin/update_agents
    ```


  * If you want the latest...
    ```
    cd config/deploy
    git pull
    ```


# Removal is something like this (untested)

  ```
  git submodule deinit --all
  rm -rf .git/modules/ecs-deploy
  git rm -f config/deploy
  ```
