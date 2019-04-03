#!/usr/bin/env bash


git config --global user.email "tester@testinetics.com"
git config --global user.name "Unit Test"
git config --global push.default simple

cd /var/md_feed

echo "git clone $REPO_SSHUSER@$MDFEED_HOST:$MDFEED_REPO ."
git clone $REPO_SSHUSER@$MDFEED_HOST:$MDFEED_REPO .
cp -pr /opt/md_feed/* .
git add --all
git commit 'add html resources'
