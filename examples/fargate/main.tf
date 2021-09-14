provider "aws" {
  region = local.region
}

module "eks" {
  source = "../.."

  cluster_name    = local.cluster_name
  cluster_version = "1.21"

  vpc_id          = local.vpc.vpc_id
  subnets         = [local.vpc.private_subnets[0], local.vpc.public_subnets[1]]
  fargate_subnets = [local.vpc.private_subnets[2]]

  fargate_profiles = {
    default = {
      name = "default"
      selectors = [
        {
          namespace = "kube-system"
          labels = {
            k8s-app = "kube-dns"
          }
        },
        {
          namespace = "default"
          labels = {
            WorkerType = "fargate"
          }
        }
      ]

      tags = {
        Owner = "default"
      }
    }

    #    # @todo: There is an open issue - https://github.com/terraform-aws-modules/terraform-aws-eks/issues/1245
    #    secondary = {
    #      name = "secondary"
    #      selectors = [
    #        {
    #          namespace = "default"
    #           labels = {
    #             Environment = "test"
    #             GithubRepo  = "terraform-aws-eks"
    #             GithubOrg   = "terraform-aws-modules"
    #           }
    #        }
    #      ]
    #
    #      # Using specific subnets instead of the ones configured in EKS (`subnets` and `fargate_subnets`)
    #      subnets = [local.vpc.private_subnets[1]]
    #
    #      tags = {
    #        Owner = "secondary"
    #      }
    #    }
  }

  manage_aws_auth = false

  tags = {
    Environment = "test"
    GithubRepo  = "terraform-aws-eks"
    GithubOrg   = "terraform-aws-modules"
  }
}

##############################################
# Calling submodule with existing EKS cluster
##############################################

module "fargate_profile_existing_cluster" {
  source = "../../modules/fargate"

  cluster_name = local.barebone_eks.cluster_id
  subnets      = [local.vpc.private_subnets[0], local.vpc.private_subnets[1]]

  fargate_profiles = {
    profile1 = {
      name = "profile1"
      selectors = [
        {
          namespace = "kube-system"
          labels = {
            k8s-app = "kube-dns"
          }
        },
        {
          namespace = "profile"
          labels = {
            WorkerType = "fargate"
          }
        }
      ]

      tags = {
        Owner = "default"
      }
    }
  }

  tags = {
    DoYouLoveFargate = "Yes"
  }
}

#############
# Kubernetes
#############

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

################################################################################
# Supporting resources (managed in "_bootstrap" directory)
################################################################################

data "terraform_remote_state" "bootstrap" {
  backend = "local"

  config = {
    path = "../_bootstrap/terraform.tfstate"
  }
}

locals {
  region       = data.terraform_remote_state.bootstrap.outputs.region
  cluster_name = data.terraform_remote_state.bootstrap.outputs.cluster_name
  vpc          = data.terraform_remote_state.bootstrap.outputs.vpc
  barebone_eks = data.terraform_remote_state.bootstrap.outputs.barebone_eks
}
