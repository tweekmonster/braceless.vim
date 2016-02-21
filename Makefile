DOCKER = docker run -it --rm -v $(PWD):/testplugin -v $(PWD)/test/vim:/home tweekmonster/ubuntu-vims

test: test-dirs
	$(DOCKER) vim-trusty '+Vader test/test.vader'

test-print: test-dirs
	$(DOCKER) vim-trusty '+Vader! test/test.vader'

run-precise:
	$(DOCKER) vim-precise -u /home/vimrc_full

run-trusty:
	$(DOCKER) vim-trusty -u /home/vimrc_full

test-dirs: test/vim/plugins

test/vim/plugins:
	mkdir -p $@
	cd $@ && git clone https://github.com/junegunn/vader.vim
	cd $@ && git clone https://github.com/Lokaltog/vim-easymotion
	cd $@ && git clone https://github.com/Raimondi/delimitMate
	cd $@ && git clone https://github.com/tpope/vim-scriptease

clean:
	rm -rf test/vim/plugins

.PHONY: test test-dirs clean
