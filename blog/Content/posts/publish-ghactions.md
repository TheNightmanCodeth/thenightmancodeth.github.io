# Using GitHub actions to deploy Publish sites to GitHub Pages

I just spent a good few weeks looking for a good static site generator and in my journey found [Publish](https://github.com/JohnSundell/Publish). While this article isn’t about that, I highly recommend using Publish if you’re a Swift developer looking for a good static site generator!

While `Publish` comes with a built-in deployment function that works with GH Pages, *I* couldn't get it to work. It looks like it really only works if you’re deploying to a separate repository. Even then, a lot of us wish to automatically trigger a publish on each new blog post or git commit. I spent some time yesterday messing with GitHub Actions and put together a build script that can do just that.

## The Process

I started off trying to simply spin up a macOS machine, cloning my repo, installing the `publish` command line tool from `homebrew`, generating the `HTML` and pushing that to my GitHub Pages branch. 

This proved to be a bit of a hassle. GitHub actions uses a version of macOS that is too old to work with the `publish` command line tool that is available through `homebrew`. 

“Okay,” I thought. “I’ll just build the command line tool from the source code.” Well, that didn’t work either. I was missing some swift concurrency libraries on the worker machine. That meant, I assume, the version of `Swift` on the GH Actions build machine was too old ☹️.

At this point I considered giving up, until I remembered `Swift` is cross platform! 🎉🎉

I set the runner to use `ubuntu-latest` instead of `macOS-latest` and got to thinking. 

On `Ubuntu` the steps would be a bit different. First and foremost I’d need to install `Swift`. Luckily there exists an action on the GitHub Actions Marketplace called `[Install Swift on Linux](https://github.com/marketplace/actions/install-swift-on-linux)` which does just that: installs Swift on a Linux worker on Github Actions! Lucky day! 

After Swift was installed I’d need to either get the `publish` command line tool building on Linux or figure out a way to build the project some other way. 🤞

Luckily (spoiler alert) the `publish` tool compiled and installed just fine on Ubuntu.

The last step was to push the resulting `Output` directory to my GitHub pages branch on my repo. Luckily there exists an awesome action on the GitHub Marketplace that makes doing that extremely easy. It’s called [Deploy to GitHub Pages](https://github.com/marketplace/actions/deploy-to-github-pages) and it works like a charm!

Now that we’ve outlined the approach let’s get to making the workflow!

## Before we start...

This will *not* be a GitHub Pages tutorial. In order to follow along here, you should already have GitHub Pages setup using one of your repos. You can check out the [Creating a GitHub Pages Site](https://docs.github.com/en/pages/getting-started-with-github-pages/creating-a-github-pages-site) article for more info. Basically you'll create a new repository, name it `<yourgithubusername>.github.io` and configure the settings there.

## Creating the Workflow

To get started creating the workflow we’ll open up a terminal and `cd` into our project’s root directory. 

Once there, we create the directory `.github/workflows` and create a new file inside there called `main.yml`.

```bash
mkdir -p .github/workflows
touch .github/workflows/main.yml
```

Now we open up our favorite text editor and start configuring our workflow!

```console
nvim .github/workflows/main.yml
```

First, we name our workflow:

```yaml
name: Deploy to GitHub Pages
```

Next, we trigger the workflow when the branch with our source code receives a push. In my case, the source code for my blog is located on the `Publish` branch. 

```yaml
on:
  push:
    branches: [ “Publish” ]
```

Finally we begin the actual workflow. First we tell the worker to use `ubuntu-latest` and use the marketplace action mentioned above to install the latest version of `Swift`.

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Install Swift
        uses: sersoft-gmbh/swifty-linux-action@v1
        with:
          release-version: 5.6.2
```

With our worker configured and swift installed we can move on to the next step: installing the `publish` command line tool.

Inside of the `steps` section we add the following:

```yaml
- name: Install Publish
  run: |
    git clone https://github.com/JohnSundell/Publish.git
    cd Publish
    make
```

Now we can pull our repo to the worker and generate our static website!

```yaml
      - uses: actions/checkout@v3
      
      - name: Generate site
        run: |
          cd $GITHUB_WORKSPACE/blog/
          publish generate
```

A few things are going on here. First we use the `checkout` action from GitHub that pulls our repo from the branch that this `main.yml` is located on. The `checkout` action pulls the source code to `$GITHUB_WORKSPACE`, so we `cd` to that path. In my case, the source code is located inside of a subdirectory called `blog`, so I change directories to `$GITHUB_WORKSPACE/blog`. Once inside that directory we call `publish generate` to generate our static website. 

Lastly we’ll use the `github-pages-deploy-action` to deploy our static site to our GitHub Pages branch!

```yaml
        - name: Deploy site
          uses: JamesIves/github-pages-deploy-action@v4
            with:
              branch: master
              folder: blog/Output
```

And just like that, our workflow is complete! In the last step we tell the `github-pages-deploy-action` which branch to deploy to, you might set this to `gh-pages` depending on your configuration. Then we tell it where our static site is located. In my case it’s located in the `Output` folder inside of the `blog` folder inside of the root of my repo. Yours might just be `folder: Output`. 

After all of that, your `.github/workflows/main.yml` file should look something like this:

```yaml

name: Deploy to GHPages

on:
  push:
    branches: [ "Publish" ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Install Swift
        uses: sersoft-gmbh/swifty-linux-action@v1
        with:
          release-version: 5.6.2

      - name: Install Publish
        run: |
          git clone https://github.com/JohnSundell/Publish.git
          cd Publish
          make

      - uses: actions/checkout@v3

      - name: Generate site
        run: |
          cd $GITHUB_WORKSPACE/blog/
          publish generate

      - name: Publish site
        uses: JamesIves/github-pages-deploy-action@v4
        with:
          branch: master
          folder: blog/Output
```

Now commit and push that file to your repo and go to the `actions` tab. 

![GitHub Actions](/img/ghactions.png)