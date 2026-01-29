#!/bin/bash                                                                                   
  # TMDB API 反向代理一键部署脚本                                                               
                                                                                                
  set -e                                                                                        
                                                                                                
  # 颜色                                                                                        
  RED='\033[0;31m'                                                                              
  GREEN='\033[0;32m'                                                                            
  YELLOW='\033[1;33m'                                                                           
  NC='\033[0m'                                                                                  
                                                                                                
  echo -e "${GREEN}========================================${NC}"                               
  echo -e "${GREEN}   TMDB API 反向代理 一键部署脚本${NC}"                                      
  echo -e "${GREEN}========================================${NC}"                               
  echo ""                                                                                       
                                                                                                
  # 检查 root                                                                                   
  if [ "$(id -u)" != "0" ]; then                                                                
      echo -e "${RED}请使用 root 用户运行此脚本${NC}"                                           
      exit 1                                                                                    
  fi                                                                                            
                                                                                                
  # 获取用户输入                                                                                
  read -p "请输入域名（如 tmdb.example.com）: " DOMAIN                                          
  if [ -z "$DOMAIN" ]; then                                                                     
      echo -e "${RED}域名不能为空${NC}"                                                         
      exit 1                                                                                    
  fi                                                                                            
                                                                                                
  read -p "请输入 TMDB API Key（留空则不自动追加）: " API_KEY                                   
                                                                                                
  read -p "是否配置 HTTPS 证书？(y/n，默认 y): " SETUP_SSL                                      
  SETUP_SSL=${SETUP_SSL:-y}                                                                     
                                                                                                
  if [ "$SETUP_SSL" = "y" ]; then                                                               
      read -p "请输入邮箱（用于 Let's Encrypt）: " EMAIL                                        
      if [ -z "$EMAIL" ]; then                                                                  
          echo -e "${RED}邮箱不能为空${NC}"                                                     
          exit 1                                                                                
      fi                                                                                        
  fi                                                                                            
                                                                                                
  echo ""                                                                                       
  echo -e "${YELLOW}配置确认：${NC}"                                                            
  echo -e "  域名：${GREEN}${DOMAIN}${NC}"                                                      
  echo -e "  API Key：${GREEN}${API_KEY:-不追加}${NC}"                                          
  echo -e "  HTTPS：${GREEN}${SETUP_SSL}${NC}"                                                  
  echo ""                                                                                       
  read -p "确认开始安装？(y/n): " CONFIRM                                                       
  if [ "$CONFIRM" != "y" ]; then                                                                
      echo "已取消"                                                                             
      exit 0                                                                                    
  fi                                                                                            
                                                                                                
  # 安装 Nginx                                                                                  
  echo ""                                                                                       
  echo -e "${GREEN}[1/4] 安装 Nginx...${NC}"                                                    
  if command -v apt &> /dev/null; then                                                          
      apt update -y && apt install -y nginx curl                                                
  elif command -v yum &> /dev/null; then                                                        
      yum install -y epel-release && yum install -y nginx curl                                  
  elif command -v dnf &> /dev/null; then                                                        
      dnf install -y nginx curl                                                                 
  else                                                                                          
      echo -e "${RED}不支持的系统，请手动安装 Nginx${NC}"                                       
      exit 1                                                                                    
  fi                                                                                            
                                                                                                
  # 生成 Nginx 配置                                                                             
  echo -e "${GREEN}[2/4] 生成 Nginx 配置...${NC}"                                               
                                                                                                
  if [ -n "$API_KEY" ]; then                                                                    
      API_KEY_BLOCK=$(cat << APIEOF                                                             
          set \$new_args \$args;                                                                
          if (\$args = "") {                                                                    
              set \$new_args "api_key=${API_KEY}";                                              
          }                                                                                     
          if (\$args != "") {                                                                   
              set \$new_args "\${args}&api_key=${API_KEY}";                                     
          }                                                                                     
  APIEOF                                                                                        
  )                                                                                             
      PROXY_PASS="proxy_pass https://api.themoviedb.org\$uri?\$new_args;"                       
  else                                                                                          
      API_KEY_BLOCK=""                                                                          
      PROXY_PASS="proxy_pass https://api.themoviedb.org;"                                       
  fi                                                                                            
                                                                                                
  cat > /etc/nginx/conf.d/tmdb-proxy.conf << EOF                                                
  server {                                                                                      
      listen 80;                                                                                
      server_name ${DOMAIN};                                                                    
                                                                                                
      location / {                                                                              
  ${API_KEY_BLOCK}                                                                              
                                                                                                
          ${PROXY_PASS}                                                                         
          proxy_set_header Host api.themoviedb.org;                                             
          proxy_ssl_server_name on;                                                             
          proxy_set_header X-Real-IP \$remote_addr;                                             
          proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;                         
          proxy_connect_timeout 60s;                                                            
          proxy_send_timeout 120s;                                                              
          proxy_read_timeout 120s;                                                              
      }                                                                                         
  }                                                                                             
  EOF                                                                                           
                                                                                                
  # 删除默认站点（避免冲突）                                                                    
  rm -f /etc/nginx/sites-enabled/default 2>/dev/null                                            
                                                                                                
  # 启动 Nginx                                                                                  
  echo -e "${GREEN}[3/4] 启动 Nginx...${NC}"                                                    
  nginx -t                                                                                      
  systemctl restart nginx                                                                       
  systemctl enable nginx                                                                        
                                                                                                
  # 配置 HTTPS                                                                                  
  if [ "$SETUP_SSL" = "y" ]; then                                                               
      echo -e "${GREEN}[4/4] 配置 HTTPS 证书...${NC}"                                           
      if command -v apt &> /dev/null; then                                                      
          apt install -y certbot python3-certbot-nginx                                          
      elif command -v yum &> /dev/null; then                                                    
          yum install -y certbot python3-certbot-nginx                                          
      elif command -v dnf &> /dev/null; then                                                    
          dnf install -y certbot python3-certbot-nginx                                          
      fi                                                                                        
      certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL"                    
  else                                                                                          
      echo -e "${YELLOW}[4/4] 跳过 HTTPS 配置${NC}"                                             
  fi                                                                                            
                                                                                                
  # 测试                                                                                        
  echo ""                                                                                       
  echo -e "${GREEN}========================================${NC}"                               
  echo -e "${GREEN}   部署完成！${NC}"                                                          
  echo -e "${GREEN}========================================${NC}"                               
  echo ""                                                                                       
  echo -e "测试命令："                                                                          
  if [ "$SETUP_SSL" = "y" ]; then                                                               
      echo -e "  ${YELLOW}curl https://${DOMAIN}/3/movie/popular${NC}"                          
  else                                                                                          
      echo -e "  ${YELLOW}curl http://${DOMAIN}/3/movie/popular${NC}"                           
  fi                                                                                            
  echo ""                                                                                       
  echo -e "MoviePilot 配置："                                                                   
  echo -e "  TMDB API Host: ${GREEN}${DOMAIN}${NC}"                                             
  if [ -n "$API_KEY" ]; then                                                                    
      echo -e "  API Key: ${GREEN}已内置，可留空${NC}"                                          
  fi                                                                                            
  echo ""                                                                                       
  echo -e "${YELLOW}注意：请确保域名 ${DOMAIN} 已解析到本机 IP${NC}"
