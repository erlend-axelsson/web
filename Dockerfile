FROM elixir:1.19.4-otp-28-alpine AS build

COPY . /usr/src/web/
WORKDIR /usr/src/web
ENV MIX_ENV="prod"
RUN ["mix", "deps.get" ,"--only prod"]
RUN ["mix", "release"]

FROM alpine:3.23.2 AS run
WORKDIR /usr/rel/web
RUN apk update && apk add --no-cache libgcc libstdc++ libncursesw
COPY --from=build /usr/src/web/_build/prod/rel/web/ .
CMD ["bin/web", "start"]