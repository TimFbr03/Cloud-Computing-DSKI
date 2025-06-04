deploy:
	cd terraform && \
	terraform init && \
	terraform apply -auto-approve && \
	sleep 30 && \
	cd ../ansible && \
	ansible-playbook -i inventory.ini playbook.yml

destroy:
	cd terraform && \
	terraform destroy -auto-approve