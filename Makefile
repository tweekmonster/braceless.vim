TEST_CMD = vim -u test/vimrc '+Vader! test/**'

test: .test/plugins
	$(TEST_CMD) > /dev/null

.test/plugins:
	mkdir -p $@
	curl -fLo .test/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
	vim -u test/vimrc +PlugInstall +qall > /dev/null

clean:
	rm -rf .test

.PHONY: test clean
