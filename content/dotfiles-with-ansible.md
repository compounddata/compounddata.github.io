---
title: "dotfiles with ansible"
date: 2021-05-23T17:09:53+10:00
---

I've used [stow](https://www.gnu.org/software/stow/) for a while to manage my `dotfiles` but recently have moved to `ansible`.

One problem I had with `stow` was how to handle _work_ and _personal_ dotfiles. Consider `gitconfig` where `user.email` would be my personal email address for my _personal_ machines and my work email address for my _work_ machine.  Using ansible templates to handle this using a single `gitconfig` _template_ is the solution that I'm finding is working nicely for me right now.

