FROM node:18-alpine
WORKDIR /src/app
RUN npm install -g yarn
COPY . .
RUN yarn install
RUN yarn build
EXPOSE 1337
CMD ["yarn", "develop"]
