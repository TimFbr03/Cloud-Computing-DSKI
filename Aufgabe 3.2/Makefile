deploy:
	cd terraform && \
	terraform init && \
	terraform apply -auto-approve && \
	sleep 60 && \
	cd ../ansible && \
	ansible-playbook -i inventory/inventory.ini deploy.yaml

destroy:
	cd terraform && \
	terraform destroy -auto-approve

update:
	cd terraform && \
	terraform destroy -auto-approve && \
	terraform init && \
	terraform apply -auto-approve && \
	sleep 60 && \
	cd ../ansible && \
	ansible-playbook -i inventory/inventory.ini deploy.yaml

rollback:
	cd terraform && \
	terraform destroy -auto-approve && \
	terraform init && \
	terraform apply -auto-approve && \
	sleep 60 && \
	cd ../ansible && \
	ansible-playbook -i inventory/inventory.ini deploy.yaml