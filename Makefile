.PHONY: clean install test

clean:
	rm -f Gemfile.lock gemfiles/*.lock

install:
	bundle && bundle exec appraisal install

test:
	bundle exec appraisal rake test integration
