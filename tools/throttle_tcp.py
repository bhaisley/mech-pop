#!/usr/bin/env python3
"""Loopback-only byte pacing for reproducible WebSocket bandwidth checks."""
import argparse
import asyncio
import json


async def run(args):
    connections = set()

    async def bridge(client_reader, client_writer):
        if len(connections) >= 8:
            client_writer.close()
            return
        task = asyncio.current_task()
        connections.add(task)
        server_writer = None
        pumps = []
        try:
            server_reader, server_writer = await asyncio.open_connection("127.0.0.1", args.upstream_port)

            async def pump(reader, writer):
                while data := await reader.read(2048):
                    await asyncio.sleep(len(data) / args.bytes_per_second)
                    writer.write(data)
                    await writer.drain()

            pumps = [asyncio.create_task(pump(client_reader, server_writer)), asyncio.create_task(pump(server_reader, client_writer))]
            await asyncio.wait(pumps, return_when=asyncio.FIRST_COMPLETED)
        except (ConnectionError, OSError):
            pass
        finally:
            for pump in pumps:
                pump.cancel()
            await asyncio.gather(*pumps, return_exceptions=True)
            for writer in [client_writer, server_writer]:
                if writer:
                    writer.close()
                    try:
                        await writer.wait_closed()
                    except (ConnectionError, OSError):
                        pass
            connections.discard(task)

    server = await asyncio.start_server(bridge, "127.0.0.1", args.listen_port)
    print(json.dumps({"listening": args.listen_port, "upstream": args.upstream_port, "bytes_per_second_per_connection_each_direction": args.bytes_per_second}), flush=True)
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--listen-port", type=int, required=True)
    parser.add_argument("--upstream-port", type=int, required=True)
    parser.add_argument("--bytes-per-second", type=int, required=True)
    args = parser.parse_args()
    if not 1024 <= args.listen_port <= 65535 or not 1024 <= args.upstream_port <= 65535 or not 1000 <= args.bytes_per_second <= 10_000_000:
        parser.error("Use unprivileged ports and a rate of 1,000–10,000,000 bytes/second")
    try:
        asyncio.run(run(args))
    except KeyboardInterrupt:
        pass
