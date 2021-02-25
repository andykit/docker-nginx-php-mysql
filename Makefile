# Makefile for Docker Nginx PHP Composer MySQL

include .env

# MySQL
MYSQL_DUMPS_DIR=data/db/dumps

help:
	@echo ""
	@echo "usage: make COMMAND"
	@echo ""
	@echo "Commands:"
	@echo "  apidoc              Generate documentation of API"
	@echo "  code-sniff          Check the API with PHP Code Sniffer (PSR2)"
	@echo "  clean               Clean directories for reset"
	@echo "  composer-up         Update PHP dependencies with composer"
	@echo "  docker-start        Create and start containers"
	@echo "  docker-stop         Stop and clear all services"
	@echo "  gen-certs           Generate SSL certificates"
	@echo "  logs                Follow log output"
	@echo "  mysql-dump          Create backup of all databases"
	@echo "  mysql-restore       Restore backup of all databases"
	@echo "  phpmd               Analyse the API with PHP Mess Detector"
	@echo "  test                Test application"

init:  
	@cp $(shell pwd)/web/edusoho/app/config/parameters.yml.docker.dist $(shell pwd)/web/edusoho/app/config/parameters.yml 2> /dev/null
	@rm -rf $(shell pwd)/web/edusoho/app/cache $(shell pwd)/web/edusoho/app/logs $(shell pwd)/web/edusoho/app/data $(shell pwd)/web/edusoho/web/files $(shell pwd)/web/edusoho/node_modules
	@mkdir -p $(shell pwd)/web/edusoho/app/cache $(shell pwd)/web/edusoho/app/logs $(shell pwd)/web/edusoho/app/data $(shell pwd)/web/edusoho/web/files
	@chmod 777 $(shell pwd)/web/edusoho/app/cache $(shell pwd)/web/edusoho/app/logs $(shell pwd)/web/edusoho/app/data $(shell pwd)/web/edusoho/web/files

stable-up: 
	@if [ -d web/edusoho ]; then git -C web/edusoho pull; else git clone --depth=1 -b stable git@github.com:andykit/ilabweb-es.git web/edusoho; fi
	@make init

clean:
	@rm -Rf data/db/mysql/*
	@rm -Rf $(MYSQL_DUMPS_DIR)/*
	@rm -Rf etc/ssl/*
	@rm -Rf web/*

# ilabweb专用命令
composer-up: stable-up
	@docker run --rm -v $(shell pwd)/web/edusoho:/app andypau/ilabweb-php7-cli sh -c "composer update"

front-up: stable-up
	@docker run --rm -v $(shell pwd)/web/edusoho:/app -w "/app" node:lts sh -c "yarn && yarn compile"

mysql-init: 
	@docker-compose exec -T -w "/var/www/html/edusoho" php  sh -c " php bin/phpmig migrate && php app/console system:init"

mysql-reset:
	@docker exec -i $(shell docker-compose ps -q mysqldb) mysql -u"$(MYSQL_ROOT_USER)" -p"$(MYSQL_ROOT_PASSWORD)" -e 'DROP DATABASE `edusoho`' 2>/dev/null
	@docker exec -i $(shell docker-compose ps -q mysqldb) mysql -u"$(MYSQL_ROOT_USER)" -p"$(MYSQL_ROOT_PASSWORD)" -e 'CREATE DATABASE `edusoho` DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci' 2>/dev/null

# 通用命令
docker-start: init
	docker-compose up -d

docker-stop:
	@docker-compose down -v
	@make clean

gen-certs:
	@docker run --rm -v $(shell pwd)/etc/ssl:/certificates -e "SERVER=$(NGINX_HOST)" jacoelho/generate-certificate

logs:
	@docker-compose logs -f

mysql-dump:
	@mkdir -p $(MYSQL_DUMPS_DIR)
	@docker exec $(shell docker-compose ps -q mysqldb) mysqldump --all-databases -u"$(MYSQL_ROOT_USER)" -p"$(MYSQL_ROOT_PASSWORD)" > $(MYSQL_DUMPS_DIR)/db.sql 2>/dev/null
	@make resetOwner

mysql-restore:
	@docker exec -i $(shell docker-compose ps -q mysqldb) mysql -u"$(MYSQL_ROOT_USER)" -p"$(MYSQL_ROOT_PASSWORD)" < $(MYSQL_DUMPS_DIR)/db.sql 2>/dev/null

# phpmd:
# 	@docker-compose exec -T php \
# 	./app/vendor/bin/phpmd \
# 	./app/src text cleancode,codesize,controversial,design,naming,unusedcode

# test: code-sniff
# 	@docker-compose exec -T php ./app/vendor/bin/phpunit --colors=always --configuration ./app/
# 	@make resetOwner

# code-sniff:
# 	@echo "Checking the standard code..."
# 	@docker-compose exec -T php ./app/vendor/bin/phpcs -v --standard=PSR2 app/src

# apidoc:
# 	@docker run --rm -v $(shell pwd):/data phpdoc/phpdoc -i=vendor/ -d /data/web/app/src -t /data/web/app/doc
# 	@make resetOwner

resetOwner:
	@chown -Rf $(SUDO_USER):$(shell id -g -n $(SUDO_USER)) $(MYSQL_DUMPS_DIR) "$(shell pwd)/etc/ssl" "$(shell pwd)/web/app" 2> /dev/null

.PHONY: clean test init stable-up front-up