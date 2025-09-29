FROM eclipse-temurin:17-jdk-focal AS builder
WORKDIR /app
COPY .mvn/ .mvn
COPY mvnw pom.xml ./
RUN ./mvnw dependency:go-offline
COPY src ./src
RUN ./mvnw clean install -DskipTests

FROM eclipse-temurin:17-jre-focal
WORKDIR /app
RUN groupadd --gid 1001 appgroup && \
    useradd --uid 1001 --gid 1001 --shell /bin/bash --create-home appuser
COPY --from=builder /app/target/*.jar app.jar

RUN chown appuser:appgroup /app && \
    chown appuser:appgroup /app/app.jar

USER appuser

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]