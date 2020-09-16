provider "kubernetes" {
  config_context_cluster   = "minikube"
}

provider "aws" {
  region  = "ap-south-1"
  profile = "rohan"	
}
resource "aws_security_group" "allow_sql" {
     name        = "mydb-sg"
     description = "Allow sql"
     ingress {
          description = "for sql"
          from_port   = 3306
          to_port     = 3306
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
     }
     egress {
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
     }
     tags = {
          Name = "mydb-sg"
     }
}



resource "aws_db_instance" "my-db" {
     allocated_storage    = 20
     storage_type         = "gp2"
     engine               = "mysql"
     engine_version       = "5.7"
     instance_class       = "db.t2.micro"
     name                 = "mydb"
     username             = "myuser"
     password             = "mypassword"
     vpc_security_group_ids = ["${aws_security_group.allow_sql.id}",]
     parameter_group_name = "default.mysql5.7"
     publicly_accessible  = true
     skip_final_snapshot  = true
}

output "name" {
  value = "${aws_db_instance.my-db}"
}

resource "kubernetes_deployment" "example" {
  metadata {
    name = "wpdeployment"
    labels = {
      test = "myexampleapp"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        test = "myexampleapp"
      }
    }

    template {
      metadata {
        labels = {
          test = "myexampleapp"
        }
      }

      spec {
        container {
          image = "wordpress:4.8-apache"
          name  = "wpcon1"
        env {
               name = "WORDPRESS_DB_HOST"
               value = aws_db_instance.my-db.endpoint
                   }
                   env {
                        name = "WORDPRESS_DB_DATABASE"
                        value = aws_db_instance.my-db.name
                   }
                   env {
                        name = "WORDPRESS_DB_USER"
                        value = aws_db_instance.my-db.username
                   }
                   env {
                        name = "WORDPRESS_DB_PASSWORD"
                        value = aws_db_instance.my-db.password
                   }
        }
      }
    }
}
}
resource "kubernetes_service" "loadbalancer" {
  depends_on=[kubernetes_deployment.example,]
  metadata {
    name = "lb"
  }
  spec {
    selector = {
      test = "myexampleapp"
    }
  port {
   protocol = "TCP"
   port = 80
   target_port = 80
  }
    type = "NodePort"
  }
}

