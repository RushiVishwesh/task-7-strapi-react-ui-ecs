FROM node:18-alpine
WORKDIR /src/app
COPY . .
RUN npm install
RUN npm run build
EXPOSE 1337
CMD ["npm", "start"]
