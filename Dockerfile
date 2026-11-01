FROM node:16.13.1-alpine AS build
ENV VUE_APP_NETEASE_API_URL=/api
WORKDIR /app
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories &&\\
\tapk add --no-cache python3 make g++ git
COPY package.json yarn.lock ./
RUN yarn config set electron_mirror https://npmmirror.com/mirrors/electron/ && \\
    yarn config set registry https://registry.npmmirror.com && \\
    sed -i 's/registry.yarnpkg.com/registry.npmmirror.com/g' yarn.lock && \\
    sed -i 's/registry.npmjs.org/registry.npmmirror.com/g' yarn.lock && \\
    yarn install
COPY . .
RUN yarn build

# Use a modern Node.js runtime for the API and current transitive dependencies.
FROM node:22-alpine AS app

RUN apk add --no-cache nginx \\
  && npm config set registry https://registry.npmmirror.com

WORKDIR /app
COPY --from=build /app/package.json /usr/local/lib/package.json
RUN API_VERSION=$(node -p "require('/usr/local/lib/package.json').dependencies['@neteaseapireborn/api']") \\
  && npm i -g "@neteaseapireborn/api@$API_VERSION" \\
  && rm -f /usr/local/lib/package.json

RUN mkdir -p /usr/share/nginx/html
COPY --from=build /app/docker/nginx.conf.example /etc/nginx/http.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

CMD ["sh", "-c", "nginx && exec npx @neteaseapireborn/api@latest"]
