# CS6650HW6_Terraform

### Start
Make sure you are in us-west-2 Oregon.
Create a Cloud9 environment.

    Choose New EC2 Instance
    Instance Type t2.micro 
    Select Secure Shell for Network Setting

Clone this repo to Cloud9.
cd into the repo folder

### Install Packer and Terraform

Install [Packer](https://developer.hashicorp.com/packer/tutorials/docker-get-started/get-started-install-cli) on Amazon Linux
    ```console
        curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
        sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
        sudo apt-get update && sudo apt-get install packer
    ```

Install [Terraform](https://aws-quickstart.github.io/workshop-terraform-modules/40_setup_cloud9_ide/42_install_terraform_c9.html) 
    ```console
        wget https://releases.hashicorp.com/terraform/0.15.1/terraform_0.15.1_linux_amd64.zip
        unzip terraform_0.15.1_linux_amd64.zip
        sudo mv terraform /usr/local/bin
    ```
### Build the AMI
```console
packer init .
packer validate ami.pkr.hcl
packer build ami.pkr.hcl
```
Once success, You can navigate to AMI to confirm. You will need the pre-baked AMI ID next.

### Run Terraform

Update the default value of ```ami_id``` in main.tf to your pre-baked AMI ID and save.

```console
terraform init
terraform validate
terraform apply
```
Enter 'yes' to continue

### Test
With your Load Balancer address, use Postman to send Get and Post requests to your server.

```
// Example Get
http://ENTER.ALB.DNS.NAME/count

//Example Post
http://ENTER.ALB.DNS.NAME/insert
```

### Clean Up

```console
terraform destroy
```

Enter 'yes' to confirm

### Author
Ruidi Huang