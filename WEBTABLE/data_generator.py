from faker import Faker
import random
import happybase
from datetime import datetime, timedelta
import hashlib
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def generate_salted_key(domain, path):
    reversed_domain = '.'.join(reversed(domain.split('.')))
    reversed_path = '/'.join(reversed(path.split('/')))
    key_body = f"{reversed_domain}:{reversed_path}"
    salt = int(hashlib.md5((domain + path).encode()).hexdigest(), 16) % 10
    return f"{salt}:{key_body}"

def main():
    try:
        connection = happybase.Connection('localhost', timeout=30000)
        table = connection.table('webtable')

        fake = Faker()
        domains = ['example.com', 'test.org', 'web.site', 'demo.net', 'sample.edu']
        status_codes = [200, 200, 200, 200, 404, 500]  # Mostly 200s

        for i in range(20):
            try:
                domain = random.choice(domains)
                path = '/'.join(fake.uri_path().split('/')[:3])
                url = f"https://{domain}/{path}"
                row_key = generate_salted_key(domain, path)

                content_size = random.choice(['small', 'medium', 'large'])
                if content_size == 'small':
                    content = fake.text(max_nb_chars=500)
                elif content_size == 'medium':
                    content = fake.text(max_nb_chars=2000)
                else:
                    content = fake.text(max_nb_chars=10000)

                created = fake.date_time_between(start_date='-1y', end_date='now')
                modified = created + timedelta(days=random.randint(0, 30))

                outlinks = [f"https://{random.choice(domains)}/{fake.uri_path()}" for _ in range(random.randint(1, 5))]

                table.put(row_key, {
                    'content:html': content,
                    'metadata:title': fake.sentence(),
                    'metadata:status': str(random.choice(status_codes)),
                    'metadata:created': created.isoformat(),
                    'metadata:modified': modified.isoformat(),
                    'outlinks:list': ','.join(outlinks)
                })

                logger.info(f"Inserted page: {url} as {row_key}")

                if i > 5 and random.random() > 0.7:
                    try:
                        source_pages = list(table.scan(limit=5))
                        if source_pages:
                            source_page = random.choice(source_pages)[0]
                            table.put(source_page, {'inlinks:list': url})
                            logger.info(f"Added inbound link from {source_page.decode()} to {url}")
                    except Exception as e:
                        logger.warning(f"Failed to add inbound link: {str(e)}")

            except Exception as e:
                logger.error(f"Error processing page {i}: {str(e)}")
                continue

    except Exception as e:
        logger.error(f"Fatal error: {str(e)}")
    finally:
        connection.close()
        logger.info("Connection closed")

if __name__ == "__main__":
    main()

