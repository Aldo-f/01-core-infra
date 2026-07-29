FROM node:20-alpine
WORKDIR /app
RUN npm install -g http-server
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["npx", "http-server", "-p", "3000", "--cors"]
