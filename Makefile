DOCKER = docker run -it --rm -v $(PWD):/testplugin -v $(PWD)/test/vim:/home tweekmonster/ubuntu-vims
TEST_ARGS = '+Vader! test/*.vader'

test: test-dirs
	$(DOCKER) vim-trusty $(TEST_ARGS)

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

clean:
	rm -rf test/vim/plugins

.PHONY: test test-dirs clean
