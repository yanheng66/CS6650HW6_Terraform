# CS6650HW6_Terraform

### Start
Make sure you are in us-west-2 Oregon.
Create a Cloud9 environment.
Clone this repo to Cloud9.

### Install Packer and Terraform

Install [Packer](https://developer.hashicorp.com/packer/tutorials/docker-get-started/get-started-install-cli) on Amazon Linux

Install [Terraform](https://aws-quickstart.github.io/workshop-terraform-modules/40_setup_cloud9_ide/42_install_terraform_c9.html) 

### Build the AMI
```console
packer init .
packer validate ami.pkr.hcl
packer build ami.pkr.hcl
```
Once successfully, You can navigate to AMI to confirm. You will the pre-baked AMI ID.

### Run Terraform

Update the default value of ```ami_id``` to your pre-baked AMI ID and save.

```console
terraform init
terraform validate
terraform apply
```
Optionaly, run ```terraform plan``` to verify execution plan.

### Test
With your Load Balancer address, use Postman to send Get and Post requests to your server.
```
// Example Get
http://demo-alb-xxx.us-west-2.elb.amazonaws.com/count

//Example Post
http://demo-alb-xxx.us-west-2.elb.amazonaws.com/insert
```

### Clean Up

```console
terraform destroy
```


### Author
Ruidi Huang