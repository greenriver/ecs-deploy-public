# Deployment with ECS

Generic resources to script ECS deployments.

# Set Up

  This is all from within the application you want to deploy

  * Add this repository as a git submodule, usually at `config/deploy`

    git submodule add --name ecs -b production git@github.com:greenriver/ecs-deploy-public.git .ecs-deploy
    git submodule init

  * Make a folder called config/docker_assets

    ```
    mkdir -p config/docker_assets
    ```

  * copy workflow directory

    ```
    mkdir -p .github/workflows

    cp .ecs-deploy/.github/workflows/ecs.yml .github/workflows/ecs.yml
    ```

  * Symlink in config for rememberable access

    ```
    cd config
    ln -s ../.ecs-deploy deploy

  * Symlink binaries

    ```
    cd bin
    ln -nsf ../.ecs-deploy/bin/bootstrap_databases .
    ln -nsf ../.ecs-deploy/bin/clear_cache
    ln -nsf ../.ecs-deploy/bin/deploy
    ln -nsf ../.ecs-deploy/bin/list
    ln -nsf ../.ecs-deploy/bin/list_domains
    ln -nsf ../.ecs-deploy/bin/mark_spot_instances
    ln -nsf ../.ecs-deploy/bin/migrate
    ln -nsf ../.ecs-deploy/bin/only_web_deploy
    ln -nsf ../.ecs-deploy/bin/poll_state
    ln -nsf ../.ecs-deploy/bin/cssh
    ln -nsf ../.ecs-deploy/bin/tail_logs
    ln -nsf ../.ecs-deploy/bin/test_build
    ln -nsf ../.ecs-deploy/bin/update_agents
    ```


  * If you want the latest...
    ```
    cd .ecs-deploy
    git pull
    ```


# Removal is something like this (untested)

  ```
  git submodule deinit --all
  git rm -f .ecs-deploy
  ```
