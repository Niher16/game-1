#!/usr/bin/env node

/**
 * Godot MCP Server
 * 
 * This MCP server enables GitHub Copilot to interact directly with your Godot project.
 * It can read project structure, create/modify scripts, and understand Godot-specific files.
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import fs from "fs/promises";
import path from "path";

class GodotMCPServer {
  constructor() {
    this.server = new Server(
      {
        name: "godot-mcp-server",
        version: "0.1.0",
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupToolHandlers();
    this.setupErrorHandling();
  }

  setupErrorHandling() {
    this.server.onerror = (error) => console.error("[MCP Error]", error);
    process.on("SIGINT", async () => {
      await this.server.close();
      process.exit(0);
    });
  }

  setupToolHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: "read_godot_project",
          description: "Read and analyze the structure of a Godot project",
          inputSchema: {
            type: "object",
            properties: {
              project_path: {
                type: "string",
                description: "Path to the Godot project directory",
              },
            },
            required: ["project_path"],
          },
        },
        {
          name: "create_gdscript",
          description: "Create a new GDScript file with specified content",
          inputSchema: {
            type: "object",
            properties: {
              file_path: {
                type: "string",
                description: "Path where the script should be created (relative to project)",
              },
              content: {
                type: "string",
                description: "GDScript content to write to the file",
              },
              class_name: {
                type: "string",
                description: "Optional class name for the script",
              },
            },
            required: ["file_path", "content"],
          },
        },
        {
          name: "read_gdscript",
          description: "Read the content of an existing GDScript file",
          inputSchema: {
            type: "object",
            properties: {
              file_path: {
                type: "string",
                description: "Path to the GDScript file to read",
              },
            },
            required: ["file_path"],
          },
        },
        {
          name: "modify_gdscript",
          description: "Modify an existing GDScript file by adding or replacing functions",
          inputSchema: {
            type: "object",
            properties: {
              file_path: {
                type: "string",
                description: "Path to the GDScript file to modify",
              },
              function_name: {
                type: "string",
                description: "Name of the function to add or replace",
              },
              function_content: {
                type: "string",
                description: "Complete function code to add or replace",
              },
              insert_after: {
                type: "string",
                description: "Optional: Insert after this line (for new functions)",
              },
            },
            required: ["file_path", "function_name", "function_content"],
          },
        },
        {
          name: "create_scene_template",
          description: "Create a basic scene file template (.tscn)",
          inputSchema: {
            type: "object",
            properties: {
              scene_path: {
                type: "string",
                description: "Path where the scene should be created",
              },
              root_node_type: {
                type: "string",
                description: "Type of root node (e.g., Node2D, Control, RigidBody2D)",
                default: "Node2D",
              },
              scene_name: {
                type: "string",
                description: "Name for the scene",
              },
            },
            required: ["scene_path", "scene_name"],
          },
        },
        {
          name: "analyze_project_structure",
          description: "Get an overview of the entire Godot project structure",
          inputSchema: {
            type: "object",
            properties: {
              project_path: {
                type: "string",
                description: "Path to the Godot project directory",
              },
            },
            required: ["project_path"],
          },
        },
      ],
    }));

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case "read_godot_project":
            return await this.readGodotProject(args.project_path);
          
          case "create_gdscript":
            return await this.createGDScript(args.file_path, args.content, args.class_name);
          
          case "read_gdscript":
            return await this.readGDScript(args.file_path);
          
          case "modify_gdscript":
            return await this.modifyGDScript(
              args.file_path, 
              args.function_name, 
              args.function_content, 
              args.insert_after
            );
          
          case "create_scene_template":
            return await this.createSceneTemplate(
              args.scene_path, 
              args.root_node_type || "Node2D", 
              args.scene_name
            );
          
          case "analyze_project_structure":
            return await this.analyzeProjectStructure(args.project_path);

          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        return {
          content: [
            {
              type: "text",
              text: `Error: ${error.message}`,
            },
          ],
        };
      }
    });
  }

  async readGodotProject(projectPath) {
    try {
      const projectFile = path.join(projectPath, "project.godot");
      const projectContent = await fs.readFile(projectFile, "utf-8");
      
      // Parse basic project info
      const projectInfo = this.parseProjectFile(projectContent);
      
      // Get directory structure
      const structure = await this.getDirectoryStructure(projectPath);
      
      return {
        content: [
          {
            type: "text",
            text: `Godot Project Analysis:
Project Name: ${projectInfo.name || "Unknown"}
Godot Version: ${projectInfo.version || "Unknown"}

Project Structure:
${structure}

Project Configuration:
${projectContent.substring(0, 500)}...`,
          },
        ],
      };
    } catch (error) {
      throw new Error(`Failed to read Godot project: ${error.message}`);
    }
  }

  async createGDScript(filePath, content, className) {
    try {
      // Ensure the directory exists
      const dir = path.dirname(filePath);
      await fs.mkdir(dir, { recursive: true });
      
      // Add class_name if provided
      let scriptContent = content;
      if (className) {
        scriptContent = `class_name ${className}\n\n${content}`;
      }
      
      // Ensure proper GDScript formatting
      if (!scriptContent.startsWith("extends")) {
        scriptContent = `extends Node\n\n${scriptContent}`;
      }
      
      await fs.writeFile(filePath, scriptContent, "utf-8");
      
      return {
        content: [
          {
            type: "text",
            text: `Successfully created GDScript file: ${filePath}
${className ? `Class name: ${className}` : ""}
Content preview:
${scriptContent.substring(0, 200)}...`,
          },
        ],
      };
    } catch (error) {
      throw new Error(`Failed to create GDScript: ${error.message}`);
    }
  }

  async readGDScript(filePath) {
    try {
      const content = await fs.readFile(filePath, "utf-8");
      const analysis = this.analyzeGDScript(content);
      
      return {
        content: [
          {
            type: "text",
            text: `GDScript File: ${filePath}

Analysis:
- Extends: ${analysis.extends}
- Class Name: ${analysis.className || "None"}
- Functions: ${analysis.functions.join(", ") || "None"}
- Variables: ${analysis.variables.join(", ") || "None"}
- Signals: ${analysis.signals.join(", ") || "None"}

Full Content:
${content}`,
          },
        ],
      };
    } catch (error) {
      throw new Error(`Failed to read GDScript: ${error.message}`);
    }
  }

  async modifyGDScript(filePath, functionName, functionContent, insertAfter) {
    try {
      let content = await fs.readFile(filePath, "utf-8");
      const lines = content.split("\n");
      
      // Find existing function and replace it, or add new function
      const functionRegex = new RegExp(`^func\\s+${functionName}\\s*\\(`, "m");
      const existingFunctionMatch = content.match(functionRegex);
      
      if (existingFunctionMatch) {
        // Replace existing function
        const functionStartIndex = content.indexOf(existingFunctionMatch[0]);
        const beforeFunction = content.substring(0, functionStartIndex);
        const afterFunctionStart = content.substring(functionStartIndex);
        
        // Find the end of the function (next function or end of file)
        const nextFunctionMatch = afterFunctionStart.substring(1).match(/^func\s+\w+/m);
        const functionEnd = nextFunctionMatch ? 
          functionStartIndex + 1 + nextFunctionMatch.index : 
          content.length;
        
        const afterFunction = content.substring(functionEnd);
        content = beforeFunction + functionContent + "\n\n" + afterFunction;
      } else {
        // Add new function
        if (insertAfter) {
          const insertIndex = content.indexOf(insertAfter);
          if (insertIndex !== -1) {
            const lineEnd = content.indexOf("\n", insertIndex);
            content = content.substring(0, lineEnd + 1) + 
                     "\n" + functionContent + "\n" + 
                     content.substring(lineEnd + 1);
          } else {
            content += "\n\n" + functionContent;
          }
        } else {
          content += "\n\n" + functionContent;
        }
      }
      
      await fs.writeFile(filePath, content, "utf-8");
      
      return {
        content: [
          {
            type: "text",
            text: `Successfully modified ${filePath}
${existingFunctionMatch ? "Replaced" : "Added"} function: ${functionName}

Function content:
${functionContent}`,
          },
        ],
      };
    } catch (error) {
      throw new Error(`Failed to modify GDScript: ${error.message}`);
    }
  }

  async createSceneTemplate(scenePath, rootNodeType, sceneName) {
    try {
      const dir = path.dirname(scenePath);
      await fs.mkdir(dir, { recursive: true });
      
      const sceneContent = `[gd_scene load_steps=1 format=3]

[node name="${sceneName}" type="${rootNodeType}"]
`;
      
      await fs.writeFile(scenePath, sceneContent, "utf-8");
      
      return {
        content: [
          {
            type: "text",
            text: `Successfully created scene template: ${scenePath}
Root node: ${rootNodeType}
Scene name: ${sceneName}

You can now open this scene in Godot and add more nodes!`,
          },
        ],
      };
    } catch (error) {
      throw new Error(`Failed to create scene template: ${error.message}`);
    }
  }

  async analyzeProjectStructure(projectPath) {
    try {
      const structure = await this.getDetailedStructure(projectPath);
      const scripts = await this.findAllScripts(projectPath);
      const scenes = await this.findAllScenes(projectPath);
      
      return {
        content: [
          {
            type: "text",
            text: `Complete Godot Project Analysis:

DIRECTORY STRUCTURE:
${structure}

GDSCRIPT FILES (${scripts.length}):
${scripts.map(script => `- ${script}`).join("\n")}

SCENE FILES (${scenes.length}):
${scenes.map(scene => `- ${scene}`).join("\n")}

DEVELOPMENT RECOMMENDATIONS:
- Keep scripts organized in dedicated folders
- Use clear naming conventions (PascalCase for classes)
- Consider creating an autoload for global game state
- Use scenes for reusable components`,
          },
        ],
      };
    } catch (error) {
      throw new Error(`Failed to analyze project structure: ${error.message}`);
    }
  }

  // Helper methods
  parseProjectFile(content) {
    const info = {};
    const lines = content.split("\n");
    
    for (const line of lines) {
      if (line.startsWith("config/name=")) {
        info.name = line.split("=")[1].replace(/"/g, "");
      }
      if (line.startsWith("config/version=")) {
        info.version = line.split("=")[1].replace(/"/g, "");
      }
    }
    
    return info;
  }

  async getDirectoryStructure(dir, prefix = "", maxDepth = 3, currentDepth = 0) {
    if (currentDepth >= maxDepth) return "";
    
    try {
      const items = await fs.readdir(dir);
      let structure = "";
      
      for (const item of items.sort()) {
        if (item.startsWith(".")) continue;
        
        const itemPath = path.join(dir, item);
        const stats = await fs.stat(itemPath);
        
        if (stats.isDirectory()) {
          structure += `${prefix}📁 ${item}/\n`;
          structure += await this.getDirectoryStructure(
            itemPath, 
            prefix + "  ", 
            maxDepth, 
            currentDepth + 1
          );
        } else {
          const icon = this.getFileIcon(item);
          structure += `${prefix}${icon} ${item}\n`;
        }
      }
      
      return structure;
    } catch (error) {
      return `${prefix}❌ Error reading directory\n`;
    }
  }

  async getDetailedStructure(projectPath) {
    return await this.getDirectoryStructure(projectPath, "", 4, 0);
  }

  async findAllScripts(projectPath) {
    const scripts = [];
    await this.findFilesByExtension(projectPath, ".gd", scripts);
    return scripts.map(script => path.relative(projectPath, script));
  }

  async findAllScenes(projectPath) {
    const scenes = [];
    await this.findFilesByExtension(projectPath, ".tscn", scenes);
    return scenes.map(scene => path.relative(projectPath, scene));
  }

  async findFilesByExtension(dir, extension, results) {
    try {
      const items = await fs.readdir(dir);
      
      for (const item of items) {
        if (item.startsWith(".")) continue;
        
        const itemPath = path.join(dir, item);
        const stats = await fs.stat(itemPath);
        
        if (stats.isDirectory()) {
          await this.findFilesByExtension(itemPath, extension, results);
        } else if (item.endsWith(extension)) {
          results.push(itemPath);
        }
      }
    } catch (error) {
      // Ignore errors for inaccessible directories
    }
  }

  analyzeGDScript(content) {
    const analysis = {
      extends: "Unknown",
      className: null,
      functions: [],
      variables: [],
      signals: [],
    };

    const lines = content.split("\n");
    
    for (const line of lines) {
      const trimmed = line.trim();
      
      if (trimmed.startsWith("extends ")) {
        analysis.extends = trimmed.substring(8);
      } else if (trimmed.startsWith("class_name ")) {
        analysis.className = trimmed.substring(11);
      } else if (trimmed.startsWith("func ")) {
        const funcMatch = trimmed.match(/func\s+(\w+)/);
        if (funcMatch) analysis.functions.push(funcMatch[1]);
      } else if (trimmed.startsWith("var ") || trimmed.startsWith("@export var ")) {
        const varMatch = trimmed.match(/var\s+(\w+)/);
        if (varMatch) analysis.variables.push(varMatch[1]);
      } else if (trimmed.startsWith("signal ")) {
        const signalMatch = trimmed.match(/signal\s+(\w+)/);
        if (signalMatch) analysis.signals.push(signalMatch[1]);
      }
    }

    return analysis;
  }

  getFileIcon(filename) {
    const ext = path.extname(filename).toLowerCase();
    const icons = {
      ".gd": "🐍",
      ".tscn": "🎬",
      ".tres": "📦",
      ".cs": "🔷",
      ".png": "🖼️",
      ".jpg": "🖼️",
      ".wav": "🔊",
      ".ogg": "🔊",
      ".mp3": "🔊",
      ".json": "📄",
      ".txt": "📝",
      ".md": "📖",
    };
    return icons[ext] || "📄";
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error("Godot MCP Server running on stdio");
  }
}

// Start the server
const server = new GodotMCPServer();
server.run().catch(console.error);