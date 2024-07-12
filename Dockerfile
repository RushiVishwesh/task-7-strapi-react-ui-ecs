FROM node:18-alpine
WORKDIR /src/app
COPY . .
RUN npm install
RUN npm install -g pm2
RUN npm run build
EXPOSE 1337
RUN pm2 start "npm run develop" --name strapi
