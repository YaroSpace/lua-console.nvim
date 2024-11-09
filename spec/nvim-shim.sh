#!/bin/sh

export XDG_CONFIG_HOME='spec/xdg/config'
export XDG_STATE_HOME='spec/xdg/local/state'
export XDG_DATA_HOME='spec/xdg/local/share'

PLUGINS_PATH='nvim/site/pack/testing/start'  
PLUGIN_NAME='lua-console.nvim'

mkdir -p ${XDG_CONFIG_HOME}/nvim
mkdir -p ${XDG_STATE_HOME}/nvim
mkdir -p ${XDG_DATA_HOME}/${PLUGINS_PATH}

export XDG_PLUGIN_PATH=${XDG_DATA_HOME}/${PLUGINS_PATH}/${PLUGIN_NAME}
ln -s $(pwd) ${XDG_PLUGIN_PATH}

nvim --cmd 'set loadplugins' -l $@
exit_code=$?

rm -rf ${XDG_CONFIG_HOME}/nvim
rm -rf ${XDG_STATE_HOME}/nvim
rm -rf ${XDG_DATA_HOME}/nvim

exit $exit_code
