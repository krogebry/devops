# Rake all the things

Why rake?  Well, it is basically like the old-school battle ax known as *make*.  With make we would bundle tasks
together to make our lives easier.  Instead of typing in uber complicated make commands, we would instead run
a make "target" which would do more things for us.

Rake expands on this idea by giving us an easy way to package ruby code into tasks ( and furthermore, namespaces )
that we can execute to make our lives easier.  Instead of running complicated commands on the CLI, we bundle these commands
into these targets and thus make our lives a little easier.  In some cases we can even reach as far
as using APIs to make interactions easier, or gather information that we pass into other commands.

Rake also allows us to tap into the magic of using modular code like gems, or even make our own.  With this we
can do things like parse JSON/YAML files into memory, then interact with them to create new things.  A great example
of this is CloudFormation, which we will get to later on.

Rake is our first step in the devops journey giving us a platform to play around with various ideas in this space.

The purpose of this document is to practice various devops-related disciplines that I have had success with in the past.
To do this we will build a simple application starting with some basic EC2 things and end up doing lots of automation
things using CloudFormation ( CF ).  Hopefully we will learn some fun things that will make your life a little easier
down the road.

# Outline

* Applicatioin layout.
* Standing up the basics with EC2.
* Moving to CloudFormation

