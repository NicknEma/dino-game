#!/bin/bash

root="$PWD"
opts=-debug

cd build > /dev/null
odin build $opts $root/source -out:dino.out
cd $root > /dev/null
