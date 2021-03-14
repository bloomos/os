#!/bin/bash

ADJECTIVES=(
    'arid'
    'bored'
    'coy'
    'deft'
    'elusive'
    'fun'
    'green'
    'hopeful'
    'indigo'
    'jumping'
    'jumbo'
    'king'
    'lime'
    'mocha'
    'neat'
    'orange'
    'purple'
    'queen'
    'red'
    'silly'
    'tuned'
    'undefined'
    'vexing'
    'wishful'
    'xenial'
    'yellow'
    'zippy'
)

NOUNS=(
    'apple'
    'bunny'
    'calf'
    'dog'
    'eft'
    'finch'
    'goose'
    'horse'
    'ibis'
    'jet'
    'kid'
    'llama'
    'mole'
    'nexus'
    'orange'
    'pig'
    'quill'
    'rabbit'
    'snail'
    'shrimp'
    'umpire'
    'valet'
    'wasp'
    'xylophone'
    'yarn'
    'zebra'
)

generate_hostname()
{
    local adj_index=$( echo $RANDOM % ${#ADJECTIVES[@]} )
    local noun_index=$( echo $RANDOM % ${#NOUNS[@]} )

    local adj=${ADJECTIVES[adj_index]}
    local noun=${NOUNS[noun_index]}

    echo "${adj}-${noun}"
}

HOSTNAME=$(generate_hostname)
hostnamectl set-hostname $HOSTNAME
