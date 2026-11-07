import logging
from contextlib import contextmanager

import psycopg2
from psycopg2 import pool

from core import config

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class DataBase:
    _pool = None

    def __init__(self):
        self._initialize_pool()

    def _initialize_pool(self):
        if DataBase._pool is None:
            try:
                DataBase._pool = psycopg2.pool.ThreadedConnectionPool(
                    1, 20,
                    host=config.DB_HOST,
                    database=config.DB_NAME,
                    user=config.DB_USER,
                    password=config.DB_PASSWORD,
                    port=config.DB_PORT
                )
                logger.info("Database connection pool initialized.")
            except Exception as e:
                logger.error(f"Error initializing connection pool: {e}")
                raise

    def get_conn(self):
        return DataBase._pool.getconn()

    def put_conn(self, conn):
        DataBase._pool.putconn(conn)

    @contextmanager
    def transacao(self):
        """Cursor de uma transação única: confirma ao sair do bloco e desfaz se houver exceção.

        Uso:
            with DataBase().transacao() as cur:
                cur.execute("SELECT ... FOR UPDATE", (...))
                cur.execute("INSERT ...", (...))
        """
        conn = self.get_conn()
        try:
            with conn.cursor() as cursor:
                yield cursor
            conn.commit()
        except BaseException:
            conn.rollback()
            raise
        finally:
            self.put_conn(conn)

    def execute(self, sql, params=None, many=True):
        conn = self.get_conn()
        try:
            with conn.cursor() as cursor:
                cursor.execute(sql, params)
                if cursor.description:
                    result = cursor.fetchall() if many else cursor.fetchone()
                else:
                    result = None
                return result
        except Exception as e:
            logger.error(f"Error executing SELECT: {e}")
            raise
        finally:
            self.put_conn(conn)

    def commit(self, sql, params=None):
        conn = self.get_conn()
        try:
            with conn.cursor() as cursor:
                cursor.execute(sql, params)
                result = cursor.fetchone() if cursor.description else None
                conn.commit()
                return result
        except Exception as e:
            conn.rollback()
            logger.error(f"Error executing COMMIT: {e}")
            raise
        finally:
            self.put_conn(conn)

    def execute_non_query(self, query, params=None):
        conn = self.get_conn()
        try:
            with conn.cursor() as cursor:
                cursor.execute(query, params)
                conn.commit()
                affected = cursor.rowcount
                return affected
        except Exception as e:
            conn.rollback()
            logger.error(f"Error executing NON-QUERY: {e}")
            raise
        finally:
            self.put_conn(conn)