FROM node:18-alpine
WORKDIR /src/app
COPY . .
RUN yarn install
RUN yarn build
EXPOSE 1337
CMD ["yarn", "develop"]
