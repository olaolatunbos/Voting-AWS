package worker;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.fasterxml.jackson.core.JsonProcessingException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import redis.clients.jedis.Jedis;
import redis.clients.jedis.exceptions.JedisConnectionException;

/**
 * Covers the parts of {@link Worker} that run without a live Redis or Postgres. The connection
 * bootstrap loops are excluded on purpose: they block until the real services answer.
 */
class WorkerTest {

    @Nested
    @DisplayName("parseVote")
    class ParseVote {

        @Test
        void readsVoterIdAndValue() throws JsonProcessingException {
            // The shape the vote service pushes onto the `votes` list.
            Worker.Vote vote = Worker.parseVote("{\"voter_id\":\"abc123\",\"vote\":\"a\"}");

            assertEquals("abc123", vote.voterId());
            assertEquals("a", vote.value());
        }

        @Test
        void ignoresUnknownFields() throws JsonProcessingException {
            Worker.Vote vote =
                    Worker.parseVote("{\"voter_id\":\"abc123\",\"vote\":\"b\",\"extra\":true}");

            assertEquals("abc123", vote.voterId());
            assertEquals("b", vote.value());
        }

        @Test
        @DisplayName("missing fields yield empty strings rather than null")
        void missingFieldsBecomeEmptyStrings() throws JsonProcessingException {
            // path().asText() is null-safe, so a malformed entry cannot NPE the loop.
            Worker.Vote vote = Worker.parseVote("{}");

            assertEquals("", vote.voterId());
            assertEquals("", vote.value());
        }

        @Test
        void rejectsMalformedJson() {
            assertThrows(JsonProcessingException.class, () -> Worker.parseVote("not json"));
        }
    }

    @Nested
    @DisplayName("isDbConnected")
    class IsDbConnected {

        @Test
        void trueWhenOpenAndValid() throws SQLException {
            Connection connection = mock(Connection.class);
            when(connection.isClosed()).thenReturn(false);
            when(connection.isValid(anyInt())).thenReturn(true);

            assertTrue(Worker.isDbConnected(connection));
        }

        @Test
        void falseWhenNull() {
            assertFalse(Worker.isDbConnected(null));
        }

        @Test
        void falseWhenClosed() throws SQLException {
            Connection connection = mock(Connection.class);
            when(connection.isClosed()).thenReturn(true);

            assertFalse(Worker.isDbConnected(connection));
        }

        @Test
        @DisplayName("a driver-level failure reads as disconnected, not an exception")
        void falseWhenDriverThrows() throws SQLException {
            Connection connection = mock(Connection.class);
            when(connection.isClosed()).thenThrow(new SQLException("connection reset"));

            assertFalse(Worker.isDbConnected(connection));
        }
    }

    @Nested
    @DisplayName("isRedisConnected")
    class IsRedisConnected {

        @Test
        void trueWhenPingPongs() {
            Jedis redis = mock(Jedis.class);
            when(redis.isConnected()).thenReturn(true);
            when(redis.ping()).thenReturn("PONG");

            assertTrue(Worker.isRedisConnected(redis));
        }

        @Test
        void falseWhenNull() {
            assertFalse(Worker.isRedisConnected(null));
        }

        @Test
        void falseWhenSocketIsDown() {
            Jedis redis = mock(Jedis.class);
            when(redis.isConnected()).thenReturn(true);
            when(redis.ping()).thenThrow(new JedisConnectionException("broken pipe"));

            assertFalse(Worker.isRedisConnected(redis));
        }
    }

    @Nested
    @DisplayName("updateVote")
    class UpdateVote {

        @Test
        void insertsANewVote() throws SQLException {
            Connection connection = mock(Connection.class);
            PreparedStatement insert = mock(PreparedStatement.class);
            when(connection.prepareStatement("INSERT INTO votes (id, vote) VALUES (?, ?)"))
                    .thenReturn(insert);

            Worker.updateVote(connection, "abc123", "a");

            verify(insert).setString(1, "abc123");
            verify(insert).setString(2, "a");
            verify(insert).executeUpdate();
            verify(connection, never()).prepareStatement("UPDATE votes SET vote = ? WHERE id = ?");
        }

        @Test
        @DisplayName("a repeat voter switches their vote instead of failing")
        void updatesOnUniqueViolation() throws SQLException {
            Connection connection = mock(Connection.class);
            PreparedStatement insert = mock(PreparedStatement.class);
            PreparedStatement update = mock(PreparedStatement.class);
            when(connection.prepareStatement("INSERT INTO votes (id, vote) VALUES (?, ?)"))
                    .thenReturn(insert);
            when(connection.prepareStatement("UPDATE votes SET vote = ? WHERE id = ?"))
                    .thenReturn(update);
            // 23505 is Postgres' unique_violation: this voter already has a row.
            when(insert.executeUpdate()).thenThrow(new SQLException("duplicate key", "23505"));

            Worker.updateVote(connection, "abc123", "b");

            // Note the reversed parameter order in the UPDATE: vote first, id second.
            verify(update).setString(1, "b");
            verify(update).setString(2, "abc123");
            verify(update).executeUpdate();
        }

        @Test
        void propagatesFailuresFromTheFallbackUpdate() throws SQLException {
            Connection connection = mock(Connection.class);
            PreparedStatement insert = mock(PreparedStatement.class);
            when(connection.prepareStatement("INSERT INTO votes (id, vote) VALUES (?, ?)"))
                    .thenReturn(insert);
            when(insert.executeUpdate()).thenThrow(new SQLException("duplicate key", "23505"));
            when(connection.prepareStatement("UPDATE votes SET vote = ? WHERE id = ?"))
                    .thenThrow(new SQLException("connection reset"));

            // main() treats this as fatal and exits, so the loop cannot silently drop votes.
            assertThrows(SQLException.class, () -> Worker.updateVote(connection, "abc123", "b"));
        }
    }
}
