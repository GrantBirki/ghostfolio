run:
	@echo "\033[0;34m[#] Killing old docker processes\033[0m"
	docker-compose down -t 1

	@echo "\033[0;34m[#] Building docker containers\033[0m"
	docker-compose --env-file ./.env -f docker-compose.yml up -d

	@echo "\e[32m[#] Containers are now running!\e[0m"

stop:
	@echo "\033[0;34m[#] Killing old docker processes\033[0m"

	docker-compose down -t 1

	@echo "\e[32m[#] Containers are now stopped!\e[0m"
