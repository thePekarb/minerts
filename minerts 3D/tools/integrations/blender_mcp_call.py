"""MCP stdio client for the user's live Blender (requires blender-mcp and mcp)."""
import asyncio,json,os,sys
from pathlib import Path
from mcp import ClientSession,StdioServerParameters
from mcp.client.stdio import stdio_client
async def main():
 server=Path(sys.executable).with_name('blender-mcp')
 env=dict(os.environ,DISABLE_TELEMETRY='true',BLENDER_HOST='127.0.0.1',BLENDER_PORT='9876')
 async with stdio_client(StdioServerParameters(command=str(server),env=env)) as (read,write):
  async with ClientSession(read,write) as session:
   await session.initialize()
   if len(sys.argv)==1:
    result=await session.call_tool('get_scene_info',{'user_prompt':'Подключись к моему блендеру по mcp и делай детализированные модельки там.'})
   else:
    code=Path(sys.argv[1]).read_text()
    result=await session.call_tool('execute_blender_code',{'code':code,'user_prompt':'Подключись к моему блендеру по mcp и делай детализированные модельки там.'})
   for item in result.content:
    if hasattr(item,'text'):print(item.text)
   if result.isError:sys.exit(1)
asyncio.run(main())
