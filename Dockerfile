FROM node:18-alpine
WORKDIR /src/app
COPY . .
RUN npm install
RUN npm run build
RUN npm install -g pm2
EXPOSE 1337
CMD ["pm2-runtime", "npm", "--", "run", "develop"]
