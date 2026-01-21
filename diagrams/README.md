# Diagrams Directory

This directory contains visual documentation for the Azure Key Vault Pipeline project.

## 📊 Available Diagrams

### Architecture Overview (`architecture-overview.md`)
Comprehensive architectural diagrams including:
- **System Architecture** - High-level context diagram
- **Component Architecture** - Detailed component relationships
- **Data Flow Architecture** - How data moves through the system
- **Deployment Architecture** - Azure DevOps and Azure resource structure
- **Security Architecture** - Authentication, authorization, and security layers
- **Integration Points** - External service integrations
- **Technology Stack Layers** - Tech stack breakdown

### Workflow Flowcharts (`workflow-flowcharts.md`)
Detailed process flowcharts including:
- **Complete End-to-End Pipeline Flow** - Full pipeline execution from start to finish
- **Secret Update Process** - Detailed step-by-step update workflow
- **Nested JSON Update Algorithm** - How nested key updates work
- **Backup and Rollback Process** - Backup creation and rollback procedures
- **Error Handling and Fallback Strategy** - Error handling and recovery flows

## 🔍 Viewing the Diagrams

All diagrams are created using **Mermaid** syntax, which is natively supported by:
- GitHub (automatic rendering)
- GitLab
- Azure DevOps (with extensions)
- VS Code (with Mermaid extension)
- Many markdown viewers

### Recommended Tools

1. **GitHub**: Just view the `.md` files directly on GitHub
2. **VS Code**: Install the "Markdown Preview Mermaid Support" extension
3. **Online**: Use [Mermaid Live Editor](https://mermaid.live/)
4. **CLI**: Use `mmdc` (Mermaid CLI) to export to PNG/SVG

## 📚 Related Documentation

- **Main README**: `../README.md` - Project overview and setup
- **Presentation**: `../PRESENTATION.md` - Comprehensive technical presentation
- **Quick Reference**: `../QUICK-REFERENCE.md` - Quick reference guide

## 🎨 Diagram Color Scheme

The diagrams use a consistent color scheme:

| Color | Purpose | Hex Code |
|-------|---------|----------|
| Blue | User input / Entry points | `#e1f5ff` |
| Red | Main pipeline / Critical stages | `#ff6b6b` |
| Teal | Success / Execution | `#4ecdc4` / `#95e1d3` |
| Yellow | Warnings / Approvals | `#ffd93d` |
| Dark Red | Production / High security | `#ff6b6b` |

## 📝 Notes

- All diagrams are maintained as code (Mermaid syntax)
- Version controlled alongside source code
- Easy to update and maintain
- Can be exported to various formats (PNG, SVG, PDF)
- Automatically rendered in markdown viewers

---

**Last Updated**: 2026-01-21
