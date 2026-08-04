package worker;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import redis.clients.jedis.Jedis;
import redis.clients.jedis.exceptions.JedisConnectionException;

import java.net.InetAddress;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Statement;

public class Worker {

    private static final String DB_URL = "jdbc:postgresql://db/postgres";
    private static final String DB_USER = "postgres";
    private static final String DB_PASSWORD = "postgres";

    private static final ObjectMapper MAPPER = new ObjectMapper();

    public static void main(String[] args) {
        try {
            Connection pgsql = openDbConnection();
            Jedis redis = openRedisConnection("redis");

            // Mirrors the .NET keep-alive query: something to run on an idle loop so the
            // connection does not get dropped by an idle timeout.
            Statement keepAlive = pgsql.createStatement();

            while (true) {
                // Slow down to prevent CPU spike, only query each 100ms
                Thread.sleep(100);

                // Reconnect redis if down
                if (!isRedisConnected(redis)) {
                    System.out.println("Reconnecting Redis");
                    redis = openRedisConnection("redis");
                }

                String json;
                try {
                    json = redis.lpop("votes");
                } catch (JedisConnectionException e) {
                    System.out.println("Reconnecting Redis");
                    redis = openRedisConnection("redis");
                    continue;
                }

                if (json != null) {
                    JsonNode vote = MAPPER.readTree(json);
                    String voterId = vote.path("voter_id").asText();
                    String voteValue = vote.path("vote").asText();
                    System.out.printf("Processing vote for '%s' by '%s'%n", voteValue, voterId);

                    // Reconnect DB if down
                    if (!isDbConnected(pgsql)) {
                        System.out.println("Reconnecting DB");
                        pgsql = openDbConnection();
                        keepAlive = pgsql.createStatement();
                    } else { // Normal +1 vote requested
                        updateVote(pgsql, voterId, voteValue);
                    }
                } else {
                    keepAlive.execute("SELECT 1");
                }
            }
        } catch (Exception ex) {
            ex.printStackTrace(System.err);
            System.exit(1);
        }
    }

    private static Connection openDbConnection() throws InterruptedException, SQLException {
        Connection connection;

        while (true) {
            try {
                connection = DriverManager.getConnection(DB_URL, DB_USER, DB_PASSWORD);
                break;
            } catch (SQLException e) {
                System.err.println("Waiting for db");
                Thread.sleep(1000);
            }
        }

        System.err.println("Connected to db");

        try (Statement statement = connection.createStatement()) {
            statement.execute("""
                    CREATE TABLE IF NOT EXISTS votes (
                        id VARCHAR(255) NOT NULL UNIQUE,
                        vote VARCHAR(255) NOT NULL
                    )""");
        }

        return connection;
    }

    private static Jedis openRedisConnection(String hostname) throws Exception {
        String ipAddress = InetAddress.getByName(hostname).getHostAddress();
        System.out.printf("Found redis at %s%n", ipAddress);

        while (true) {
            try {
                System.err.println("Connecting to redis");
                Jedis jedis = new Jedis(ipAddress, 6379);
                jedis.ping();
                return jedis;
            } catch (JedisConnectionException e) {
                System.err.println("Waiting for redis");
                Thread.sleep(1000);
            }
        }
    }

    private static boolean isRedisConnected(Jedis redis) {
        try {
            return redis != null && redis.isConnected() && "PONG".equalsIgnoreCase(redis.ping());
        } catch (JedisConnectionException e) {
            return false;
        }
    }

    private static boolean isDbConnected(Connection connection) {
        try {
            return connection != null && !connection.isClosed() && connection.isValid(1);
        } catch (SQLException e) {
            return false;
        }
    }

    private static void updateVote(Connection connection, String voterId, String vote) throws SQLException {
        try (PreparedStatement insert =
                     connection.prepareStatement("INSERT INTO votes (id, vote) VALUES (?, ?)")) {
            insert.setString(1, voterId);
            insert.setString(2, vote);
            insert.executeUpdate();
        } catch (SQLException e) {
            // Voter already exists (unique violation on id): switch their vote instead.
            try (PreparedStatement update =
                         connection.prepareStatement("UPDATE votes SET vote = ? WHERE id = ?")) {
                update.setString(1, vote);
                update.setString(2, voterId);
                update.executeUpdate();
            }
        }
    }
}
