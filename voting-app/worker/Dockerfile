# build compiles the program and packages it into a single runnable jar
FROM maven:3.9-eclipse-temurin-21 AS build

WORKDIR /source
# Resolve dependencies first so this layer is cached across source-only changes
COPY pom.xml .
RUN mvn -B -q dependency:go-offline

COPY src ./src
RUN mvn -B -q clean package

# app image
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /source/target/worker.jar .
ENTRYPOINT ["java", "-jar", "worker.jar"]
